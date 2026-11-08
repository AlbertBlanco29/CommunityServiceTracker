<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    // STUDENT REGISTRATION

    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        // Public registration can only create student accounts.
        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => 'student',
        ]);

        $token = $user->createToken('community-service-app')
            ->plainTextToken;

        return response()->json([
            'message' => 'Student account created successfully.',
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
            ],
        ], 201);
    }

    // LOGIN

    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where(
            'email',
            $validated['email']
        )->first();

        if (!$user ||
            !Hash::check(
                $validated['password'],
                $user->password
            )) {
            return response()->json([
                'message' => 'Invalid email or password.',
            ], 401);
        }

        $token = $user->createToken('community-service-app')
            ->plainTextToken;

        return response()->json([
            'message' => 'Login successful.',
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
            ],
        ]);
    }

    // GET LOGGED-IN USER

    public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }

    // LOGOUT

    public function logout(Request $request)
    {
        $request->user()
            ->currentAccessToken()
            ->delete();

        return response()->json([
            'message' => 'Logout successful.',
        ]);
    }
}
