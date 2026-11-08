<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AutomationLog extends Model
{
    protected $fillable = [
        'user_id',
        'event',
        'attempt',
        'status',
        'message',
        'context',
    ];

    protected function casts(): array
    {
        return [
            'attempt' => 'integer',
            'context' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
