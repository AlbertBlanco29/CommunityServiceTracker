
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reservations', function (Blueprint $table) {
            $table->id();

            $table->foreignId('activity_id')
                ->constrained('activities')
                ->restrictOnDelete();

            $table->foreignId('student_id')
                ->constrained('users')
                ->restrictOnDelete();

            // reserved, completed, cancelled
            $table->string('status', 20)->default('reserved');

            // Prevent duplicate processing during API retries
            $table->uuid('request_key')->nullable()->unique();

            $table->timestamp('reserved_at')->useCurrent();

            $table->timestamps();

            // Prevent duplicate reservations by the same student
            $table->unique(['activity_id', 'student_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reservations');
    }
};
