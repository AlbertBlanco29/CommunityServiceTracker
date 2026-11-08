<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activities', function (Blueprint $table) {
            $table->id();

            $table->string('title', 150);
            $table->string('category', 100);
            $table->text('description')->nullable();

            $table->string('location', 180);
            $table->date('activity_date');

            $table->unsignedSmallInteger('estimated_hours')->default(1);
            $table->unsignedInteger('capacity')->default(1);

            // available, reserved, approved
            $table->string('status', 20)->default('available');

            $table->timestamps();

            $table->index(['status', 'activity_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activities');
    }
};
