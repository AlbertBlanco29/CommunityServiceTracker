<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AutomationLog;
use App\Models\Reservation;
use App\Models\ServiceHour;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Throwable;

class ServiceHourController extends Controller
{
    // ==========================================
    // VIEW SERVICE HOURS
    // ==========================================

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        if (!in_array($user->role, ['admin', 'student'])) {
            return response()->json([
                'message' => 'Unauthorized access.',
            ], 403);
        }

        $query = ServiceHour::with([
            'reservation.activity',
            'reservation.student',
            'reviewer',
        ])->latest();

        // Students can only view their own submissions.

        if ($user->role === 'student') {
            $query->whereHas('reservation', function ($q) use ($user) {
                $q->where('student_id', $user->id);
            });
        }

        return response()->json([
            'message' => 'Service hours retrieved successfully.',
            'data' => $query->get(),
        ]);
    }

    // ==========================================
    // STUDENT SUBMITS SERVICE HOURS
    // ==========================================

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->role !== 'student') {
            return response()->json([
                'message' => 'Only students can submit service hours.',
            ], 403);
        }

        $validated = $request->validate([
            'reservation_id' => 'required|integer|exists:reservations,id',
            'hours' => 'required|numeric|gt:0|max:24',
            'description' => 'required|string|max:2000',
        ]);

        try {
            $result = DB::transaction(function () use (
                $validated,
                $user
            ) {
                $reservation = Reservation::where(
                    'student_id',
                    $user->id
                )
                    ->lockForUpdate()
                    ->find($validated['reservation_id']);

                if (!$reservation) {
                    return [
                        'error' => 'Reservation not found or does not belong to you.',
                        'http_status' => 404,
                    ];
                }

                if (!in_array($reservation->status, [
                    'reserved',
                    'completed',
                ])) {
                    return [
                        'error' => 'This reservation cannot receive service hours.',
                        'http_status' => 409,
                    ];
                }

                $existing = ServiceHour::where(
                    'reservation_id',
                    $reservation->id
                )->lockForUpdate()->first();

                if ($existing) {
                    if ($existing->approval_status === 'approved') {
                        return [
                            'error' => 'These service hours have already been approved.',
                            'http_status' => 409,
                        ];
                    }

                    if ($existing->approval_status === 'pending') {
                        return [
                            'error' => 'Your service-hour submission is awaiting review.',
                            'http_status' => 409,
                        ];
                    }

                    // Allow a student to correct and resubmit
                    // a previously rejected submission.

                    $existing->update([
                        'hours' => $validated['hours'],
                        'description' => $validated['description'],
                        'approval_status' => 'pending',
                        'reviewed_by' => null,
                        'reviewed_at' => null,
                    ]);

                    $serviceHour = $existing;
                } else {
                    $serviceHour = ServiceHour::create([
                        'reservation_id' => $reservation->id,
                        'hours' => $validated['hours'],
                        'description' => $validated['description'],
                        'approval_status' => 'pending',
                    ]);
                }

                $reservation->update([
                    'status' => 'completed',
                ]);

                return [
                    'service_hour' => $serviceHour->load([
                        'reservation.activity',
                        'reservation.student',
                    ]),
                ];
            }, 3);

            if (isset($result['error'])) {
                return response()->json([
                    'message' => $result['error'],
                ], $result['http_status']);
            }

            $this->recordLog(
                $user->id,
                'service_hour_submission',
                1,
                'success',
                'Student successfully submitted service hours.',
                [
                    'service_hour_id' => $result['service_hour']->id,
                    'reservation_id' => $validated['reservation_id'],
                ]
            );

            return response()->json([
                'message' => 'Service hours submitted successfully. Awaiting administrator approval.',
                'data' => $result['service_hour'],
            ], 201);

        } catch (Throwable $exception) {
            report($exception);

            $this->recordLog(
                $user->id,
                'service_hour_submission',
                1,
                'failed',
                'Service-hour submission failed.',
                [
                    'reservation_id' => $validated['reservation_id'],
                ]
            );

            return response()->json([
                'message' => 'Unable to submit service hours at this time.',
            ], 503);
        }
    }

    // ==========================================
    // ADMIN APPROVES SERVICE HOURS
    // ==========================================

    public function approve(
        Request $request,
        ServiceHour $serviceHour
    ): JsonResponse {
        $user = $request->user();

        if ($user->role !== 'admin') {
            return response()->json([
                'message' => 'Administrator access required.',
            ], 403);
        }

        try {
            $result = DB::transaction(function () use (
                $serviceHour,
                $user
            ) {
                $record = ServiceHour::with('reservation.activity')
                    ->lockForUpdate()
                    ->findOrFail($serviceHour->id);

                if ($record->approval_status === 'approved') {
                    return [
                        'error' => 'These service hours are already approved.',
                        'http_status' => 409,
                    ];
                }

                if ($record->approval_status !== 'pending') {
                    return [
                        'error' => 'Only pending submissions can be approved.',
                        'http_status' => 409,
                    ];
                }

                $record->update([
                    'approval_status' => 'approved',
                    'reviewed_by' => $user->id,
                    'reviewed_at' => now(),
                ]);

                $reservation = $record->reservation;
                $activity = $reservation->activity;

                // Mark the activity approved only when all
                // existing reservations have approved hours.

                $hasReservations = $activity
                    ->reservations()
                    ->exists();

                $hasUnapprovedReservations = $activity
                    ->reservations()
                    ->whereDoesntHave('serviceHour', function ($query) {
                        $query->where(
                            'approval_status',
                            'approved'
                        );
                    })
                    ->exists();

                if (
                    $hasReservations &&
                    !$hasUnapprovedReservations
                ) {
                    $activity->update([
                        'status' => 'approved',
                    ]);
                }

                return [
                    'service_hour' => $record->fresh([
                        'reservation.activity',
                        'reservation.student',
                        'reviewer',
                    ]),
                ];
            }, 3);

            if (isset($result['error'])) {
                return response()->json([
                    'message' => $result['error'],
                ], $result['http_status']);
            }

            $this->recordLog(
                $user->id,
                'service_hour_approval',
                1,
                'success',
                'Administrator approved the submitted service hours.',
                [
                    'service_hour_id' => $serviceHour->id,
                ]
            );

            return response()->json([
                'message' => 'Service hours approved successfully.',
                'data' => $result['service_hour'],
            ]);

        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'message' => 'Unable to approve service hours.',
            ], 503);
        }
    }

    // ==========================================
    // ADMIN REJECTS SERVICE HOURS
    // ==========================================

    public function reject(
        Request $request,
        ServiceHour $serviceHour
    ): JsonResponse {
        $user = $request->user();

        if ($user->role !== 'admin') {
            return response()->json([
                'message' => 'Administrator access required.',
            ], 403);
        }

        $validated = $request->validate([
            'reason' => 'required|string|max:1000',
        ]);

        try {
            $result = DB::transaction(function () use (
                $serviceHour,
                $user,
                $validated
            ) {
                $record = ServiceHour::query()
                    ->lockForUpdate()
                    ->findOrFail($serviceHour->id);

                if ($record->approval_status !== 'pending') {
                    return [
                        'error' => 'Only pending submissions can be rejected.',
                    ];
                }

                $record->update([
                    'approval_status' => 'rejected',
                    'reviewed_by' => $user->id,
                    'reviewed_at' => now(),
                    'description' => $record->description
                        . "\n\nAdministrator rejection reason: "
                        . $validated['reason'],
                ]);

                return [
                    'service_hour' => $record->fresh([
                        'reservation.activity',
                        'reservation.student',
                        'reviewer',
                    ]),
                ];
            }, 3);

            if (isset($result['error'])) {
                return response()->json([
                    'message' => $result['error'],
                ], 409);
            }

            $this->recordLog(
                $user->id,
                'service_hour_rejection',
                1,
                'success',
                'Administrator rejected the service-hour submission.',
                [
                    'service_hour_id' => $serviceHour->id,
                    'reason' => $validated['reason'],
                ]
            );

            return response()->json([
                'message' => 'Service-hour submission rejected.',
                'data' => $result['service_hour'],
            ]);

        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'message' => 'Unable to reject service hours.',
            ], 503);
        }
    }

    // ==========================================
    // STRUCTURED AUTOMATION LOG
    // ==========================================

    private function recordLog(
        int $userId,
        string $event,
        int $attempt,
        string $status,
        string $message,
        array $context = []
    ): void {
        try {
            AutomationLog::create([
                'user_id' => $userId,
                'event' => $event,
                'attempt' => $attempt,
                'status' => $status,
                'message' => $message,
                'context' => $context,
            ]);
        } catch (Throwable $exception) {
            report($exception);
        }
    }
}
