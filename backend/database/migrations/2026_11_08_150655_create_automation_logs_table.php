
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('automation_logs', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->string('event', 120);

            $table->unsignedSmallInteger('attempt')->default(1);

            // started, success, retry, recovered, failed
            $table->string('status', 20);

            $table->text('message');

            $table->json('context')->nullable();

            $table->timestamps();

            $table->index(['event', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('automation_logs');
    }
};
