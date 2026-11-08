<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Activity extends Model
{
    protected $fillable = [
        'title',
        'category',
        'description',
        'location',
        'activity_date',
        'estimated_hours',
        'capacity',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'activity_date' => 'date',
            'estimated_hours' => 'integer',
            'capacity' => 'integer',
        ];
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(Reservation::class);
    }
}
