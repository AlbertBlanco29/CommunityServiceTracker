<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ActivityController extends Controller
{
    // Only administrators can manage activities.

    private function checkAdmin(Request $request): ?JsonResponse
    {
        if (!$request->user() || $request->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Administrator access required.',
            ], 403);
        }

        return null;
    }

    // GET ALL ACTIVITIES

    public function index()
    {
        $activities = Activity::withCount('reservations')
            ->orderBy('activity_date')
            ->get()
            ->map(function ($activity) {
                $activity->remaining_slots = max(
                    0,
                    $activity->capacity - $activity->reservations_count
                );

                return $activity;
            });

        return response()->json([
            'message' => 'Activities retrieved successfully.',
            'data' => $activities,
        ]);
    }

    // GET ONE ACTIVITY

    public function show(Activity $activity)
    {
        $activity->loadCount('reservations');

        $activity->remaining_slots = max(
            0,
            $activity->capacity - $activity->reservations_count
        );

        return response()->json([
            'data' => $activity,
        ]);
    }

    // CREATE ACTIVITY

    public function store(Request $request)
    {
        if ($denied = $this->checkAdmin($request)) {
            return $denied;
        }

        $validated = $request->validate([
            'title' => 'required|string|max:150',
            'category' => 'required|string|max:100',
            'description' => 'nullable|string',
            'location' => 'required|string|max:180',
            'activity_date' => 'required|date|after_or_equal:today',
            'estimated_hours' => 'required|integer|min:1|max:24',
            'capacity' => 'required|integer|min:1|max:1000',
        ]);

        $activity = Activity::create([
            ...$validated,
            'status' => 'available',
        ]);

        return response()->json([
            'message' => 'Activity created successfully.',
            'data' => $activity,
        ], 201);
    }

    // UPDATE ACTIVITY

    public function update(Request $request, Activity $activity)
    {
        if ($denied = $this->checkAdmin($request)) {
            return $denied;
        }

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:150',
            'category' => 'sometimes|required|string|max:100',
            'description' => 'nullable|string',
            'location' => 'sometimes|required|string|max:180',
            'activity_date' => 'sometimes|required|date',
            'estimated_hours' => 'sometimes|required|integer|min:1|max:24',
            'capacity' => 'sometimes|required|integer|min:1|max:1000',
            'status' => 'sometimes|required|in:available,reserved,approved',
        ]);

        if (isset($validated['capacity'])) {
            $currentReservations = $activity->reservations()->count();

            if ($validated['capacity'] < $currentReservations) {
                return response()->json([
                    'message' => 'Capacity cannot be lower than the existing reservations.',
                ], 422);
            }
        }

        $activity->update($validated);

        return response()->json([
            'message' => 'Activity updated successfully.',
            'data' => $activity->fresh(),
        ]);
    }

    // DELETE ACTIVITY

    public function destroy(Request $request, Activity $activity)
    {
        if ($denied = $this->checkAdmin($request)) {
            return $denied;
        }

        if ($activity->reservations()->exists()) {
            return response()->json([
                'message' => 'This activity cannot be deleted because it has reservations.',
            ], 409);
        }

        $activity->delete();

        return response()->json([
            'message' => 'Activity deleted successfully.',
        ]);
    }
}
