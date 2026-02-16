<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('agent_tasks', function (Blueprint $table) {
            $table->string('id', 26)->primary(); // ULID
            $table->text('intent');
            $table->string('status', 30)->default('research');
            $table->string('risk_level', 10)->default('low');
            $table->json('plan')->nullable();
            $table->string('branch_name')->nullable();
            $table->unsignedInteger('pr_number')->nullable();
            $table->string('pr_url')->nullable();
            $table->string('commit_sha', 40)->nullable();
            $table->unsignedInteger('iterations')->default(0);
            $table->string('requested_by')->nullable();
            $table->string('channel')->nullable();
            $table->text('error')->nullable();
            $table->timestamp('deployed_at')->nullable();
            $table->timestamp('rolled_back_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index(['requested_by', 'created_at']);
        });

        Schema::create('agent_task_stages', function (Blueprint $table) {
            $table->string('id', 26)->primary(); // ULID
            $table->string('task_id', 26);
            $table->string('stage', 20);
            $table->string('status', 10);
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->json('output')->nullable();
            $table->timestamps();

            $table->foreign('task_id')
                ->references('id')
                ->on('agent_tasks')
                ->cascadeOnDelete();

            $table->index(['task_id', 'stage']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('agent_task_stages');
        Schema::dropIfExists('agent_tasks');
    }
};
