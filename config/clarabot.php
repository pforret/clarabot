<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Self-Improving Pipeline Configuration
    |--------------------------------------------------------------------------
    |
    | Controls how Clarabot develops, tests, and deploys new functionality
    | for itself. Each setting has a safe default. Adjust via .env.
    |
    */

    'self_improve' => [

        /*
        |----------------------------------------------------------------------
        | Allowed Triggers
        |----------------------------------------------------------------------
        |
        | Who can trigger the self-improvement pipeline.
        |
        | 'owner' = Only the configured owner user
        | 'all'   = Any authenticated user
        | 'none'  = Pipeline disabled
        |
        */

        'allowed_triggers' => env('CLARABOT_ALLOWED_TRIGGERS', 'owner'),

        /*
        |----------------------------------------------------------------------
        | Auto-Approve Risk Level
        |----------------------------------------------------------------------
        |
        | Maximum risk level that can be auto-approved without human review.
        |
        | 'low'    = Only auto-approve low-risk changes
        | 'medium' = Auto-approve low and medium risk
        | 'none'   = Always require human approval
        |
        */

        'auto_approve_risk' => env('CLARABOT_AUTO_APPROVE_RISK', 'low'),

        /*
        |----------------------------------------------------------------------
        | Development Iteration Limits
        |----------------------------------------------------------------------
        |
        | Maximum number of development iterations (write code → run tests →
        | fix failures) before the agent gives up and escalates to a human.
        |
        */

        'max_dev_iterations' => (int) env('CLARABOT_MAX_DEV_ITERATIONS', 10),

        /*
        |----------------------------------------------------------------------
        | CI Retry Limit
        |----------------------------------------------------------------------
        |
        | Maximum times the agent can retry fixing CI failures on a PR
        | before marking the task as failed.
        |
        */

        'max_ci_retries' => (int) env('CLARABOT_MAX_CI_RETRIES', 2),

        /*
        |----------------------------------------------------------------------
        | Observation Periods
        |----------------------------------------------------------------------
        |
        | How long to monitor the deployed application for errors before
        | declaring the deployment successful.
        |
        */

        'staging_observation_minutes' => (int) env('CLARABOT_STAGING_OBSERVE', 5),
        'production_observation_minutes' => (int) env('CLARABOT_PROD_OBSERVE', 15),

        /*
        |----------------------------------------------------------------------
        | Error Rate Threshold
        |----------------------------------------------------------------------
        |
        | Percentage of requests that can fail before triggering an
        | automatic rollback during the observation period.
        |
        */

        'error_rate_threshold' => (int) env('CLARABOT_ERROR_THRESHOLD', 5),

        /*
        |----------------------------------------------------------------------
        | Deployment Strategy
        |----------------------------------------------------------------------
        |
        | How code is deployed to staging and production.
        |
        | 'git-pull' = SSH into server and git pull (simple, single-server)
        | 'docker'   = Build and deploy Docker image
        |
        */

        'deploy_strategy' => env('CLARABOT_DEPLOY_STRATEGY', 'git-pull'),

        /*
        |----------------------------------------------------------------------
        | Rollback Migrations
        |----------------------------------------------------------------------
        |
        | Whether to also revert database migrations during a rollback.
        | If false, only the code is rolled back.
        |
        */

        'rollback_migrations' => (bool) env('CLARABOT_ROLLBACK_MIGRATIONS', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Protected Paths
    |--------------------------------------------------------------------------
    |
    | Files and directories the agent is never allowed to modify without
    | explicit human approval, regardless of risk level.
    |
    */

    'protected_paths' => [
        '.github/workflows/',
        'scripts/',
        'config/clarabot.php',
        'bootstrap/app.php',
        'app/Providers/',
    ],

    /*
    |--------------------------------------------------------------------------
    | Git Configuration
    |--------------------------------------------------------------------------
    |
    | Branch naming and merge settings for the pipeline.
    |
    */

    'git' => [
        'develop_branch' => env('CLARABOT_DEVELOP_BRANCH', 'develop'),
        'production_branch' => env('CLARABOT_PRODUCTION_BRANCH', 'main'),
        'feature_prefix' => 'feature/',
        'hotfix_prefix' => 'hotfix/',
    ],

];
