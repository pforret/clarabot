# Clarabot Self-Improving Development & Deployment Process

A system where software agents develop new functionality, test it, and deploy it over the running application — with safety gates at every stage.

---

## Overview

```
┌─────────────┐    ┌───────────┐    ┌───────────┐    ┌──────────┐    ┌───────────┐    ┌────────────┐    ┌────────────┐
│  1. Intent   │───▶│ 2. Research│───▶│ 3. Develop │───▶│ 4. Review │───▶│ 5. Staging │───▶│ 6. Promote  │───▶│ 7. Monitor  │
│  (trigger)   │    │  & Plan    │    │  & Test    │    │  & Gate   │    │  Deploy    │    │  to Prod    │    │  & Report   │
└─────────────┘    └───────────┘    └───────────┘    └──────────┘    └───────────┘    └────────────┘    └────────────┘
                                          │                │                │                │                │
                                          ▼                ▼                ▼                ▼                ▼
                                      ┌───────┐       ┌───────┐       ┌───────┐       ┌───────┐       ┌───────┐
                                      │ Abort  │       │ Abort  │       │ Abort  │       │Rollback│       │Rollback│
                                      │& Report│       │& Report│       │& Report│       │& Alert │       │& Alert │
                                      └───────┘       └───────┘       └───────┘       └───────┘       └───────┘
```

Each stage has an **exit gate** that must pass before proceeding. Any failure aborts the pipeline and notifies the requesting user.

---

## Git Branch Strategy

```
main ─────────────────────────────────●────────────────────●─────────▶  (production)
                                      ▲                    ▲
                                      │ merge              │ merge
                                      │                    │
develop ──────────●───────────────────●────────────────────●─────────▶  (staging)
                  ▲                   ▲
                  │ merge             │ merge
                  │                   │
feature/xmpp ────●───●───●───●───────┘                                  (agent branch)
                  ▲   ▲   ▲   ▲
                  │   │   │   └── fix: test failures
                  │   │   └────── add: pest tests
                  │   └────────── add: XmppDriver implementation
                  └────────────── add: xmpp-php dependency
```

| Branch | Purpose | Deploys To | Merge Policy |
|--------|---------|------------|--------------|
| `main` | Production code | Production server | PR from `develop` only, requires health check pass |
| `develop` | Integration & staging | Staging server | PR from `feature/*` branches, requires CI pass |
| `feature/*` | Agent-developed features | — (CI only) | Created by agent, auto-merged when CI passes |
| `hotfix/*` | Urgent production fixes | Staging → Production | Created by agent, fast-tracked through pipeline |

---

## Stage 1: Intent (Trigger)

The pipeline starts when a user requests a new capability. Triggers can come from:

- **Chat message** — "Hey Clarabot, please add XMPP support"
- **Webhook** — External system sends a feature request
- **Cron job** — Scheduled self-maintenance ("check for dependency updates")
- **Self-initiated** — Agent identifies an improvement during normal operation

### What happens

1. Clarabot receives the request via any channel (Telegram, WebChat, webhook, etc.)
2. Creates an internal **Task** record with:
   - `intent`: The raw user request
   - `status`: `research`
   - `requested_by`: User/channel identifier
   - `requested_at`: Timestamp
3. Creates a **GitHub Issue** (optional, for audit trail):
   ```
   Title: [Agent] Add XMPP channel support
   Body: Requested by @user via Telegram. Original message: "..."
   Labels: agent-developed, feature
   ```

### Gate: Intent Validation

- Is the request within Clarabot's domain? (not "write me a poem")
- Does the user have permission to trigger development? (configurable allowlist)
- Is there already an open task for the same intent? (deduplication)

---

## Stage 2: Research & Planning

The agent researches the feasibility and approach before writing any code.

### What happens

1. **Codebase analysis** — Understand existing patterns, contracts, and conventions
2. **External research** — Search for libraries, APIs, documentation
   - Check Packagist for PHP packages
   - Evaluate maintenance status (last commit, open issues, PHP 8.4 support)
   - Read API documentation for external services
3. **Dependency evaluation** — Can existing contracts (`ChannelDriver`, `Tool`, etc.) accommodate this?
4. **Plan creation** — Produce a structured implementation plan:
   ```
   ## Plan: XMPP Channel Support

   ### Approach
   - Use `norgul/xmpp-php` library (last release: 2024, PHP 8.x compatible)
   - Implement ChannelDriver contract for XMPP
   - Add XMPP config to config/channels.php

   ### Files to Create
   - app/Channels/XmppDriver.php
   - config entries in config/channels.php
   - database/migrations/xxxx_add_xmpp_to_channel_type.php
   - tests/Feature/Channels/XmppDriverTest.php

   ### Files to Modify
   - app/Enums/ChannelType.php (add Xmpp case)
   - composer.json (add norgul/xmpp-php)

   ### Risk Assessment
   - LOW: Library is stable, contract pattern is established
   - MEDIUM: XMPP server connectivity in CI (mock needed)
   ```

### Gate: Plan Approval

Two modes (configurable per-task complexity):

- **Auto-approve**: For low-risk changes (dependency updates, bug fixes, simple features)
- **Human-approve**: For high-risk changes (new dependencies, architectural changes, security-sensitive code). Sends the plan to the requesting user for approval before proceeding.

Risk is assessed by:
- Does it add new Composer/npm dependencies? → higher risk
- Does it modify authentication, authorization, or encryption? → requires human approval
- Does it change database schema? → higher risk
- Estimated lines of code changed → higher risk above threshold

---

## Stage 3: Development & Testing

The agent writes code, writes tests, and iterates until everything passes.

### What happens

1. **Create feature branch**:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/xmpp-support
   ```

2. **Implement in order**:
   - Migrations first (if any)
   - Models/Enums
   - Core implementation (drivers, services, etc.)
   - Configuration changes
   - Tests (Pest feature + unit tests)

3. **Local validation loop** (repeats until all pass):
   ```
   ┌─────────────────────────────────────────┐
   │                                         │
   │  Write/Edit Code                        │
   │       │                                 │
   │       ▼                                 │
   │  Run: vendor/bin/pint --dirty           │
   │       │                                 │
   │       ▼                                 │
   │  Run: php artisan test --compact        │
   │       │                                 │
   │       ├── PASS ──▶ Continue             │
   │       │                                 │
   │       └── FAIL ──▶ Analyze failures ────┘
   │                    Fix code
   │                    (max 10 iterations)
   └─────────────────────────────────────────┘
   ```

4. **Commit and push**:
   ```bash
   git add -A
   git commit -m "feat: add XMPP channel support

   - Implement XmppDriver with ChannelDriver contract
   - Add XMPP configuration to channels config
   - Add Pest feature tests for XMPP normalization and delivery

   Requested-by: user@telegram
   Agent-task: task_abc123"
   git push -u origin feature/xmpp-support
   ```

### Conventions enforced

- All code follows existing project patterns (check sibling files)
- Laravel `make:` commands used where applicable
- Form Requests for validation, not inline
- Factories and seeders for new models
- PHPDoc blocks, no inline comments unless logic is complex
- No `env()` outside config files
- No `DB::` facade — use Eloquent

### Gate: Local Quality

All must pass before creating a PR:
- [ ] `vendor/bin/pint --dirty` exits clean
- [ ] `php artisan test --compact` — zero failures
- [ ] No new security vulnerabilities introduced (no raw SQL, no unescaped output)
- [ ] Iteration count < 10 (if agent can't fix it in 10 tries, escalate to human)

---

## Stage 4: Review & Merge Gate

The code is reviewed and merged into `develop`.

### What happens

1. **Create Pull Request**:
   ```
   Title: feat: Add XMPP channel support
   Base: develop
   Head: feature/xmpp-support

   ## Summary
   - Implements XmppDriver following ChannelDriver contract
   - Adds XMPP enum case and configuration
   - 12 new Pest tests covering normalization, delivery, and error handling

   ## Agent Context
   - Task: task_abc123
   - Requested by: user@telegram
   - Research: norgul/xmpp-php selected over fabiang/xmpp (abandoned)
   - Iterations: 3 (2 test failures fixed)

   ## Test Plan
   - [x] Unit: XmppDriver normalizes inbound XMPP stanzas
   - [x] Unit: XmppDriver chunks messages at XMPP limit
   - [x] Feature: Full send/receive cycle with mocked XMPP server
   ```

2. **CI Pipeline runs** (GitHub Actions):
   - Lint (Pint)
   - Full test suite (PHP 8.4 + 8.5 matrix)
   - Build frontend assets
   - (Future: static analysis with PHPStan/Larastan)

3. **Auto-merge decision**:
   - If CI passes AND risk is low → auto-merge to `develop`
   - If CI passes AND risk is high → notify human for review
   - If CI fails → agent attempts to fix (back to Stage 3, max 2 retries)
   - If CI fails after retries → abort pipeline, notify user

### Gate: CI Must Pass

- [ ] All GitHub Actions checks green
- [ ] No merge conflicts with `develop`
- [ ] PR description includes test plan
- [ ] No files outside the expected scope were modified

---

## Stage 5: Staging Deployment

Code merged to `develop` is automatically deployed to the staging environment.

### Deployment Mechanism

Two supported strategies:

#### Strategy A: Docker-based (recommended for production parity)

```yaml
# Triggered by merge to develop
# .github/workflows/deploy-staging.yml

1. Build Docker image with new code
2. Run migrations inside container
3. Run smoke tests against staging URL
4. If healthy → update staging service
5. If unhealthy → keep old image, alert
```

#### Strategy B: Git-pull based (simpler, for single-server setups)

```bash
# scripts/deploy.sh staging
1. ssh staging "cd /app && git pull origin develop"
2. ssh staging "cd /app && composer install --no-dev"
3. ssh staging "cd /app && php artisan migrate --force"
4. ssh staging "cd /app && php artisan config:cache"
5. ssh staging "cd /app && php artisan route:cache"
6. ssh staging "cd /app && php artisan view:cache"
7. ssh staging "cd /app && npm run build"
8. ssh staging "cd /app && php artisan queue:restart"
```

### Health Checks

After staging deployment, automated checks run:

```
┌────────────────────────────────────┐
│  Staging Health Checks             │
│                                    │
│  1. HTTP: GET /healthz → 200      │
│  2. HTTP: GET /login → 200        │
│  3. DB: Can query users table     │
│  4. Queue: Can dispatch test job  │
│  5. Channels: Existing channels   │
│     still respond to ping         │
│  6. Smoke: Send test message      │
│     through each active channel   │
│     and verify response           │
│                                    │
│  Wait 5 minutes, repeat checks    │
│  If all pass → promote            │
│  If any fail → rollback staging   │
└────────────────────────────────────┘
```

### Gate: Staging Must Be Healthy

- [ ] Health endpoint returns 200
- [ ] No new exceptions in error log (compared to pre-deploy baseline)
- [ ] All existing channels still functional
- [ ] New feature responds correctly to test input
- [ ] Error rate does not increase beyond threshold (configurable, default 1%)

---

## Stage 6: Promote to Production

Once staging has been healthy for the configured observation period, the code is promoted to production.

### What happens

1. **Snapshot current production state** (for rollback):
   ```bash
   # Record current commit hash
   git -C /app rev-parse HEAD > /app/storage/.last-good-deploy

   # Backup database
   cp /app/database/database.sqlite /app/storage/backups/pre-deploy-$(date +%s).sqlite
   ```

2. **Create and merge PR** `develop` → `main`:
   - Auto-created by the pipeline
   - Title: `deploy: promote develop to production (task_abc123)`
   - Merges immediately (CI already validated on develop)

3. **Deploy to production** (same mechanism as staging):
   ```bash
   # scripts/deploy.sh production
   ```

4. **Run production health checks**:
   - Same checks as staging
   - Plus: verify the new feature works with real credentials/endpoints

### Rollback Trigger

Automatic rollback if any of these occur within the observation window (default: 15 minutes):

- Health endpoint returns non-200
- Error rate exceeds 5% of requests
- Any channel becomes unresponsive
- Queue jobs start failing at elevated rate
- Memory/CPU exceeds safety threshold

### Rollback Procedure

```bash
# scripts/rollback.sh

1. Read last known good commit from /app/storage/.last-good-deploy
2. git checkout $LAST_GOOD_COMMIT
3. composer install --no-dev --optimize-autoloader
4. php artisan migrate:rollback --step=N  (if migrations were run)
5. Restore database backup (if migration rollback fails)
6. php artisan config:cache && php artisan route:cache
7. php artisan queue:restart
8. Verify health checks pass
9. Notify user: "Deployment of [feature] rolled back due to [reason]"
```

### Gate: Production Must Be Healthy

- [ ] Health checks pass for full observation window
- [ ] Error rate within acceptable threshold
- [ ] All channels operational
- [ ] No unhandled exceptions in production logs

---

## Stage 7: Monitor & Report

After successful deployment, the pipeline reports results and continues monitoring.

### What happens

1. **Notify requesting user**:
   ```
   ✓ Feature deployed: XMPP channel support

   Summary:
   - XmppDriver implemented with full ChannelDriver contract
   - 12 tests passing
   - Deployed to production at 2026-02-16 14:30 UTC
   - Monitoring for 15 minutes — no issues detected

   You can now configure XMPP in your .env:
     XMPP_HOST=your-server.example.com
     XMPP_PORT=5222
     XMPP_USERNAME=clarabot@example.com
     XMPP_PASSWORD=...

   Then run: php artisan channel:start xmpp
   ```

2. **Close the GitHub issue** (if one was created)

3. **Update internal task record**:
   - `status`: `deployed`
   - `deployed_at`: Timestamp
   - `deploy_commit`: SHA

4. **Extended monitoring** (24 hours):
   - Check error rates every 15 minutes
   - If anomaly detected → alert user (but don't auto-rollback after observation window)

5. **Knowledge capture**:
   - Record which libraries were evaluated and why
   - Record which approaches worked/failed
   - Feed into agent memory for future tasks

---

## Pipeline Configuration

All thresholds and behaviors are configurable via `config/clarabot.php`:

```php
return [
    'self_improve' => [
        // Who can trigger the development pipeline
        'allowed_triggers' => env('CLARABOT_ALLOWED_TRIGGERS', 'owner'),
        // 'owner' = only the configured owner user
        // 'all'   = any authenticated user
        // 'none'  = disabled

        // Risk threshold for auto-approval
        'auto_approve_risk' => env('CLARABOT_AUTO_APPROVE_RISK', 'low'),
        // 'low'    = only auto-approve low-risk changes
        // 'medium' = auto-approve low and medium risk
        // 'none'   = always require human approval

        // Maximum development iterations before escalating
        'max_dev_iterations' => env('CLARABOT_MAX_DEV_ITERATIONS', 10),

        // Maximum CI retry attempts
        'max_ci_retries' => env('CLARABOT_MAX_CI_RETRIES', 2),

        // Staging observation period (minutes) before promoting
        'staging_observation_minutes' => env('CLARABOT_STAGING_OBSERVE', 5),

        // Production observation period (minutes) before declaring success
        'production_observation_minutes' => env('CLARABOT_PROD_OBSERVE', 15),

        // Error rate threshold (percentage) that triggers rollback
        'error_rate_threshold' => env('CLARABOT_ERROR_THRESHOLD', 5),

        // Deployment strategy
        'deploy_strategy' => env('CLARABOT_DEPLOY_STRATEGY', 'git-pull'),
        // 'git-pull' = simple git pull on server
        // 'docker'   = build and deploy Docker image

        // Rollback: also revert database migrations?
        'rollback_migrations' => env('CLARABOT_ROLLBACK_MIGRATIONS', true),
    ],
];
```

---

## Safety Principles

### 1. Never deploy untested code
Every line of agent-written code must be covered by a test that passes in CI. No exceptions.

### 2. Always have a rollback path
Before every deployment, snapshot the current state. If anything goes wrong, restore within seconds.

### 3. Blast radius containment
- Feature branches isolate experimental code
- Staging catches issues before production
- Observation windows catch delayed failures
- Per-feature rollback (not whole-system rollback)

### 4. Human override at every stage
- Any stage can be configured to require human approval
- Humans can abort the pipeline at any point
- Emergency stop: `php artisan clarabot:abort {task_id}`

### 5. Audit trail
Every action is logged:
- Git commits include `Agent-task: task_xxx` trailer
- PRs include full context (research, iterations, test results)
- Deployment logs are persisted
- Rollback reasons are recorded

### 6. No self-modification of safety infrastructure
The agent **cannot** modify:
- This deployment process itself
- GitHub Actions workflow files
- The rollback scripts
- Authentication/authorization code (without human approval)
- The `config/clarabot.php` safety thresholds

---

## Artisan Commands

Commands that support the self-improving pipeline:

| Command | Description |
|---------|-------------|
| `php artisan clarabot:status` | Show status of all active development tasks |
| `php artisan clarabot:tasks` | List all tasks (pending, in-progress, deployed, failed) |
| `php artisan clarabot:abort {task}` | Abort a running pipeline |
| `php artisan clarabot:approve {task}` | Manually approve a pending plan |
| `php artisan clarabot:rollback {task}` | Manually rollback a deployed task |
| `php artisan clarabot:health` | Run health checks against current environment |
| `php artisan clarabot:deploy {env}` | Manually trigger deployment to staging/production |

---

## GitHub Actions Workflows

### `agent-ci.yml` — Runs on feature/* and hotfix/* branches

Validates agent-written code:
- Lint with Pint
- Full Pest test suite (PHP 8.4 + 8.5)
- Build frontend assets
- Report results back to the agent via commit status

### `deploy-staging.yml` — Runs on merge to develop

Deploys to staging and runs health checks:
- Deploy code to staging environment
- Run migrations
- Execute smoke tests
- Report health status

### `deploy-production.yml` — Runs on merge to main

Deploys to production with safety:
- Snapshot current state
- Deploy code to production
- Run health checks
- Auto-rollback on failure
- Extended monitoring

---

## Database Schema for Pipeline State

```sql
-- Track self-improvement tasks
CREATE TABLE agent_tasks (
    id          TEXT PRIMARY KEY,        -- ULID
    intent      TEXT NOT NULL,           -- Raw user request
    status      TEXT NOT NULL DEFAULT 'research',
                -- research | planning | plan_pending_approval | developing |
                -- testing | pr_open | staging | observing | promoting |
                -- deployed | failed | rolled_back | aborted
    risk_level  TEXT DEFAULT 'low',      -- low | medium | high
    plan        TEXT,                    -- JSON: implementation plan
    branch_name TEXT,                    -- feature/xmpp-support
    pr_number   INTEGER,                -- GitHub PR number
    pr_url      TEXT,                    -- GitHub PR URL
    commit_sha  TEXT,                    -- Final deployed commit
    iterations  INTEGER DEFAULT 0,      -- Development iteration count
    requested_by TEXT,                   -- User identifier
    channel     TEXT,                    -- Channel the request came from
    error       TEXT,                    -- Last error message (if failed)
    deployed_at TIMESTAMP,
    rolled_back_at TIMESTAMP,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

-- Track each pipeline stage execution
CREATE TABLE agent_task_stages (
    id          TEXT PRIMARY KEY,
    task_id     TEXT NOT NULL REFERENCES agent_tasks(id),
    stage       TEXT NOT NULL,           -- research | plan | develop | review | staging | production | monitor
    status      TEXT NOT NULL,           -- running | passed | failed | skipped
    started_at  TIMESTAMP,
    completed_at TIMESTAMP,
    output      TEXT,                    -- JSON: stage output/logs
    created_at  TIMESTAMP
);
```

---

## Example: Full Pipeline Run

```
14:00  User sends via Telegram: "Add XMPP channel support"
14:00  → Stage 1: Create task_abc123, status=research
14:01  → Stage 2: Agent researches XMPP libraries
14:03  → Stage 2: Plan created, risk=low, auto-approved
14:03  → Stage 3: Create branch feature/xmpp-support
14:05  → Stage 3: Implement XmppDriver, write tests
14:07  → Stage 3: Tests fail (2 failures), iteration 1
14:08  → Stage 3: Fix failures, tests pass, iteration 2
14:08  → Stage 3: Pint clean, push to origin
14:09  → Stage 4: Create PR #42 → develop
14:10  → Stage 4: CI passes, auto-merge to develop
14:11  → Stage 5: Deploy to staging
14:12  → Stage 5: Health checks pass
14:17  → Stage 5: Observation period complete (5 min), all healthy
14:17  → Stage 6: Create PR #43 develop → main, merge
14:18  → Stage 6: Deploy to production, snapshot taken
14:19  → Stage 6: Health checks pass
14:34  → Stage 6: Observation period complete (15 min), all healthy
14:34  → Stage 7: Notify user "XMPP support deployed successfully"
14:34  → Stage 7: Close GitHub issue, update task status=deployed
15:34  → Stage 7: Extended monitoring — no anomalies detected
```

---

## Failure Scenarios

### Scenario: Tests never pass

```
Stage 3, iteration 10: Tests still failing
→ Agent marks task as failed
→ Creates GitHub issue with details: "Agent could not resolve test failures after 10 iterations"
→ Notifies user: "I couldn't get XMPP support working. The test failures are documented in issue #44. You may need to help me with [specific blocker]."
```

### Scenario: Staging health check fails

```
Stage 5: Health check fails — /healthz returns 500
→ Rollback staging to previous develop commit
→ Revert the merge commit on develop
→ Notify user: "XMPP deployment failed health checks on staging. Rolled back. Error: [details]"
→ Task status → failed
```

### Scenario: Production error rate spikes

```
Stage 6, minute 8 of observation: Error rate jumps to 12%
→ Immediate rollback to snapshot
→ Restore database backup
→ Verify health checks pass on rolled-back version
→ Notify user: "XMPP deployment caused elevated errors in production (12% error rate). Rolled back automatically. The staging environment didn't catch this — likely a production-specific configuration issue."
→ Task status → rolled_back
```

### Scenario: Human rejects plan

```
Stage 2: Plan sent to user for approval (risk=high, new dependency)
User responds: "Don't use norgul/xmpp-php, use the Strophe protocol directly"
→ Agent revises plan with new approach
→ Re-submits for approval
→ User approves
→ Continue to Stage 3
```
