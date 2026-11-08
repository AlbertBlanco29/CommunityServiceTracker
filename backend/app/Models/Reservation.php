<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Reservation extends Model
{
    protected $fillable = [
        'activity_id',
        'student_id',
        'status',
        'request_key',
        'reserved_at',
    ];

    protected function casts(): array
    {
        return [
            'reserved_at' => 'datetime',
        ];
    }

    public function activity(): BelongsTo
    {
        return $this->belongsTo(Activity::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function serviceHour(): HasOne
    {
        return $this->hasOne(ServiceHour::class);
    }
}
