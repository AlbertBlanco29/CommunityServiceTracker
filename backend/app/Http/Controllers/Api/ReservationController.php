<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use App\Models\AutomationLog;
use App\Models\Reservation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;

class ReservationController extends Controller
{
    // ==========================================
    // VIEW RESERVATIONS
    // ==========================================

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Reservation::with([
            'activity',
            'student',
        ])->latest();

        if ($user->role !== 'admin') {
            $query->where('student_id', $user->id);
        }

        return response()->json([
            'message' => 'Reservations retrieved successfully.',
            'data' => $query->get(),
        ]);
    }

    // ==========================================
    // CREATE RESERVATION
    // BOUNDED AUTOMATION WITH RETRY LOGGING
    // ==========================================

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $attempt = $this->readAttemptNumber($request);

        // Only students can reserve activities.
        if ($user->role !== 'student') {
            $this->recordLog(
                $user->id,
                'reservation_request_permanent_failure',
                $attempt,
                'permanent_failure',
                'Only students can reserve activities.',
                [
                    'http_status' => 403,
                    'retryable' => false,
                ]
            );

            return response()->json([
                'message' => 'Only students can reserve activities.',
                'retryable' => false,
            ], 403);
        }

        // Validate request.
        $validator = Validator::make($request->all(), [
            'activity_id' => ['required', 'integer', 'min:1'],
            'request_key' => ['required', 'uuid'],
        ]);

        if ($validator->fails()) {
            $this->recordLog(
                $user->id,
                'reservation_request_permanent_failure',
                $attempt,
                'permanent_failure',
                'Reservation request failed validation.',
                [
                    'http_status' => 422,
                    'retryable' => false,
                    'validation_errors' => $validator->errors()->toArray(),
                ]
            );

            return response()->json([
                'message' => 'The reservation details are invalid.',
                'errors' => $validator->errors(),
                'retryable' => false,
            ], 422);
        }

        $validated = $validator->validated();
        $requestKey = $validated['request_key'];

        // ==========================================
        // LOCAL-ONLY TEST FAILURE SIMULATOR
        // ==========================================

        $testMode = app()->environment('local')
            ? $request->header('X-Test-Failure')
            : null;

        // Test A: Fail attempt 1, recover on attempt 2.
        if (
            $testMode === 'transient_once' &&
            $attempt === 1
        ) {
            $this->recordLog(
                $user->id,
                'reservation_request_transient_failure',
                $attempt,
                'failed',
                'Simulated temporary failure. Retry is allowed.',
                [
                    'activity_id' => $validated['activity_id'],
                    'request_key' => $requestKey,
                    'test_mode' => 'transient_once',
                    'http_status' => 503,
                    'retryable' => true,
                ]
            );

            return response()->json([
                'message' => 'Temporary failure. Retrying.',
                'retryable' => true,
            ], 503);
        }

        // Test B: Fail all three attempts.
        if ($testMode === 'persistent_transient') {
            $finalAttempt = $attempt >= 3;

            $this->recordLog(
                $user->id,
                $finalAttempt
                    ? 'reservation_request_permanent_failure'
                    : 'reservation_request_transient_failure',
                $attempt,
                $finalAttempt
                    ? 'permanent_failure'
                    : 'failed',
                $finalAttempt
                    ? 'Maximum retry limit reached.'
                    : 'Temporary failure. Retry is allowed.',
                [
                    'activity_id' => $validated['activity_id'],
                    'request_key' => $requestKey,
                    'test_mode' => 'persistent_transient',
                    'http_status' => 503,
                    'retryable' => !$finalAttempt,
                    'retry_limit' => 3,
                ]
            );

            return response()->json([
                'message' => $finalAttempt
                    ? 'Maximum retry attempts reached.'
                    : 'Temporary failure. Retrying.',
                'retryable' => !$finalAttempt,
                'attempt' => $attempt,
                'retry_limit' => 3,
            ], 503);
        }

        try {
            // ==========================================
            // DATABASE TRANSACTION
            // ==========================================

            $result = DB::transaction(function () use (
                $validated,
                $user
            ) {
                // Lock activity to prevent overbooking.
                $activity = Activity::query()
                    ->lockForUpdate()
                    ->find($validated['activity_id']);

                if (!$activity) {
                    return [
                        'error' => 'Activity not found.',
                        'http_status' => 404,
                    ];
                }

                // ==========================================
                // CHECK REPEATED REQUEST KEY
                // ==========================================

                $existingRequest = Reservation::with([
                    'activity',
                    'student',
                ])
                    ->where(
                        'request_key',
                        $validated['request_key']
                    )
                    ->first();

                if ($existingRequest) {
                    if (
                        (int) $existingRequest->student_id !==
                            (int) $user->id ||
                        (int) $existingRequest->activity_id !==
                            (int) $activity->id
                    ) {
                        return [
                            'error' => 'This request key is already in use.',
                            'http_status' => 409,
                        ];
                    }

                    return [
                        'reservation' => $existingRequest,
                        'replayed' => true,
                    ];
                }

                // ==========================================
                // CHECK ACTIVITY STATUS
                // ==========================================

                if ($activity->status === 'approved') {
                    return [
                        'error' => 'This activity is already approved.',
                        'http_status' => 409,
                    ];
                }

                // ==========================================
                // CHECK DUPLICATE RESERVATION
                // ==========================================

                $duplicate = Reservation::query()
                    ->where('activity_id', $activity->id)
                    ->where('student_id', $user->id)
                    ->exists();

                if ($duplicate) {
                    return [
                        'error' => 'You have already reserved this activity.',
                        'http_status' => 409,
                    ];
                }

                // ==========================================
                // CHECK CAPACITY
                // ==========================================

                $reservedCount = $activity->reservations()
                    ->whereIn('status', [
                        'reserved',
                        'completed',
                    ])
                    ->count();

                if ($reservedCount >= $activity->capacity) {
                    return [
                        'error' => 'This activity is already full.',
                        'http_status' => 409,
                    ];
                }

                // ==========================================
                // SAVE RESERVATION
                // ==========================================

                $reservation = Reservation::create([
                    'activity_id' => $activity->id,
                    'student_id' => $user->id,
                    'status' => 'reserved',
                    'request_key' => $validated['request_key'],
                    'reserved_at' => now(),
                ]);

                // ==========================================
                // UPDATE ACTIVITY STATUS
                // ==========================================

                $newReservedCount = $reservedCount + 1;

                $activity->update([
                    'status' => $newReservedCount >= $activity->capacity
                        ? 'reserved'
                        : 'available',
                ]);

                $reservation->load([
                    'activity',
                    'student',
                ]);

                return [
                    'reservation' => $reservation,
                    'replayed' => false,
                ];
            }, 3);

            // ==========================================
            // HANDLE PERMANENT BUSINESS-RULE FAILURE
            // ==========================================

            if (isset($result['error'])) {
                $statusCode = (int) $result['http_status'];

                $this->recordLog(
                    $user->id,
                    'reservation_request_permanent_failure',
                    $attempt,
                    'permanent_failure',
                    $result['error'],
                    [
                        'activity_id' => $validated['activity_id'],
                        'request_key' => $requestKey,
                        'http_status' => $statusCode,
                        'retryable' => false,
                    ]
                );

                return response()->json([
                    'message' => $result['error'],
                    'retryable' => false,
                ], $statusCode);
            }

            // ==========================================
            // HANDLE REPEATED REQUEST
            // ==========================================

            if ($result['replayed']) {
                $this->recordLog(
                    $user->id,
                    'reservation_request',
                    $attempt,
                    'recovered',
                    'Previously completed reservation was safely retrieved.',
                    [
                        'reservation_id' => $result['reservation']->id,
                        'activity_id' => $validated['activity_id'],
                        'request_key' => $requestKey,
                        'replayed' => true,
                    ]
                );

                return response()->json([
                    'message' => 'Previously completed reservation recovered successfully.',
                    'replayed' => true,
                    'data' => $result['reservation'],
                ], 200);
            }

            // ==========================================
            // HANDLE SUCCESS OR RECOVERED RETRY
            // ==========================================

            $recovered = $attempt > 1;

            $this->recordLog(
                $user->id,
                'reservation_request',
                $attempt,
                $recovered ? 'recovered' : 'success',
                $recovered
                    ? 'Reservation succeeded after a retry.'
                    : 'Student successfully reserved the activity.',
                [
                    'reservation_id' => $result['reservation']->id,
                    'activity_id' => $validated['activity_id'],
                    'request_key' => $requestKey,
                    'replayed' => false,
                    'retryable' => false,
                ]
            );

            return response()->json([
                'message' => $recovered
                    ? 'Activity reservation recovered successfully after retry.'
                    : 'Activity reserved successfully.',
                'replayed' => false,
                'recovered' => $recovered,
                'data' => $result['reservation'],
            ], 201);

        } catch (Throwable $exception) {
            // ==========================================
            // HANDLE SERVER OR DATABASE FAILURE
            // ==========================================

            report($exception);

            $retryable = $attempt < 3;

            $this->recordLog(
                $user->id,
                $retryable
                    ? 'reservation_request_transient_failure'
                    : 'reservation_request_permanent_failure',
                $attempt,
                $retryable
                    ? 'failed'
                    : 'permanent_failure',
                $retryable
                    ? 'Server or database error. Retry is allowed.'
                    : 'Maximum retry limit reached.',
                [
                    'activity_id' => $validated['activity_id'],
                    'request_key' => $requestKey,
                    'error_type' => class_basename($exception),
                    'retryable' => $retryable,
                    'retry_limit' => 3,
                ]
            );

            return response()->json([
                'message' => $retryable
                    ? 'Reservation service temporarily unavailable. Retry using the same request key.'
                    : 'Reservation failed after three attempts.',
                'retryable' => $retryable,
                'attempt' => $attempt,
                'retry_limit' => 3,
            ], 503);
        }
    }

    // ==========================================
    // READ ATTEMPT NUMBER FROM FLUTTER
    // ==========================================

    private function readAttemptNumber(Request $request): int
    {
        $rawAttempt = $request->header(
            'X-Automation-Attempt',
            1
        );

        $attempt = filter_var(
            $rawAttempt,
            FILTER_VALIDATE_INT
        );

        if ($attempt === false || $attempt < 1) {
            return 1;
        }

        return min($attempt, 3);
    }

    // ==========================================
    // STRUCTURED AUTOMATION LOGGING
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