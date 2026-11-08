
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_hours', function (Blueprint $table) {
            $table->id();

            $table->foreignId('reservation_id')
                ->unique()
                ->constrained('reservations')
                ->restrictOnDelete();

            $table->decimal('hours', 5, 2);

            $table->text('description');

            // pending, approved, rejected
            $table->string('approval_status', 20)->default('pending');

            $table->foreignId('reviewed_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamp('reviewed_at')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_hours');
    }
};
