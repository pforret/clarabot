#!/usr/bin/env bash
#
# deploy.sh — Deploy Clarabot to staging or production
#
# Usage: scripts/deploy.sh <environment>
#   environment: staging | production
#
# Required environment variables (set via GitHub Secrets):
#   *_HOST, *_USER, *_PATH, DEPLOY_KEY
#   Where * is STAGING or PRODUCTION (uppercase)

set -euo pipefail

ENVIRONMENT="${1:?Usage: deploy.sh <staging|production>}"

case "$ENVIRONMENT" in
    staging)
        HOST="${STAGING_HOST:?STAGING_HOST not set}"
        USER="${STAGING_USER:?STAGING_USER not set}"
        APP_PATH="${STAGING_PATH:?STAGING_PATH not set}"
        SSH_KEY="${DEPLOY_KEY:?STAGING_DEPLOY_KEY not set}"
        BRANCH="develop"
        ;;
    production)
        HOST="${PRODUCTION_HOST:?PRODUCTION_HOST not set}"
        USER="${PRODUCTION_USER:?PRODUCTION_USER not set}"
        APP_PATH="${PRODUCTION_PATH:?PRODUCTION_PATH not set}"
        SSH_KEY="${DEPLOY_KEY:?PRODUCTION_DEPLOY_KEY not set}"
        BRANCH="main"
        ;;
    *)
        echo "Error: environment must be 'staging' or 'production'"
        exit 1
        ;;
esac

echo "==> Deploying to $ENVIRONMENT ($HOST)"
echo "    Branch: $BRANCH"
echo "    Path:   $APP_PATH"

# Set up SSH key
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
if [ -n "$SSH_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$SSH_KEY" > ~/.ssh/deploy_key
    chmod 600 ~/.ssh/deploy_key
    SSH_OPTS="$SSH_OPTS -i ~/.ssh/deploy_key"
fi

ssh_cmd() {
    ssh $SSH_OPTS "$USER@$HOST" "$@"
}

echo "==> Enabling maintenance mode"
ssh_cmd "cd $APP_PATH && php artisan down --retry=60 --refresh=5" || true

echo "==> Pulling latest code"
ssh_cmd "cd $APP_PATH && git fetch origin $BRANCH && git reset --hard origin/$BRANCH"

echo "==> Installing Composer dependencies"
ssh_cmd "cd $APP_PATH && composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader"

echo "==> Running migrations"
ssh_cmd "cd $APP_PATH && php artisan migrate --force"

echo "==> Caching configuration"
ssh_cmd "cd $APP_PATH && php artisan config:cache"
ssh_cmd "cd $APP_PATH && php artisan route:cache"
ssh_cmd "cd $APP_PATH && php artisan view:cache"
ssh_cmd "cd $APP_PATH && php artisan event:cache"

echo "==> Building frontend assets"
ssh_cmd "cd $APP_PATH && npm ci --production && npm run build"

echo "==> Restarting queue workers"
ssh_cmd "cd $APP_PATH && php artisan queue:restart"

echo "==> Disabling maintenance mode"
ssh_cmd "cd $APP_PATH && php artisan up"

echo "==> Deployment to $ENVIRONMENT complete"
echo "    Commit: $(ssh_cmd "cd $APP_PATH && git rev-parse --short HEAD")"
echo "    Time:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
