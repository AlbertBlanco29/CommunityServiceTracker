<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\ServiceHourController;


// PUBLIC AUTHENTICATION

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// AUTHENTICATED API

Route::middleware('auth:sanctum')->group(function () {

    // USER ACCOUNT

    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // ACTIVITIES

    Route::get('/activities', [ActivityController::class, 'index']);
    Route::get('/activities/{activity}', [ActivityController::class, 'show']);

    Route::post('/activities', [ActivityController::class, 'store']);
    Route::put('/activities/{activity}', [ActivityController::class, 'update']);
    Route::patch('/activities/{activity}', [ActivityController::class, 'update']);
    Route::delete('/activities/{activity}', [ActivityController::class, 'destroy']);


Route::get('/reservations', [ReservationController::class, 'index']);

Route::post('/reservations', [ReservationController::class, 'store']);


// SERVICE HOURS

Route::get('/service-hours', [ServiceHourController::class, 'index']);

Route::post('/service-hours', [ServiceHourController::class, 'store']);

Route::patch(
    '/service-hours/{serviceHour}/approve',
    [ServiceHourController::class, 'approve']
);

Route::patch(
    '/service-hours/{serviceHour}/reject',
    [ServiceHourController::class, 'reject']
);


});
