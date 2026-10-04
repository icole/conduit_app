# Deployment Guide for ConduitApp with Stream Chat

## Prerequisites

1. Ensure you have all required environment variables set in your `.env` file
2. Have Docker and Kamal installed on your local machine
3. Have SSH access to your deployment server

## Environment Variables

### Required for Stream Chat

Two Stream apps, two pairs of credentials. Keep them in the same `.env`:

```bash
# Local development (loaded by dotenv when you run bin/rails server)
STREAM_API_KEY=your_dev_stream_api_key
STREAM_API_SECRET=your_dev_stream_api_secret

# Production (what `kamal deploy` ships — see .kamal/secrets)
STREAM_PROD_API_KEY=your_production_stream_api_key
STREAM_PROD_API_SECRET=your_production_stream_api_secret
```

Inside the container the app always reads `STREAM_API_KEY` / `STREAM_API_SECRET`;
`.kamal/secrets` maps those to the `STREAM_PROD_*` values at deploy time so a plain
`source .env` can never push dev credentials to production. Staging has its own
`.env.staging` with its own `STREAM_API_KEY` pair (a third Stream app).

### Other Required Variables

```bash
# Docker Hub
DOCKER_USERNAME=your_docker_username
KAMAL_REGISTRY_PASSWORD=your_docker_password

# Server Configuration
CONDUIT_SERVER_IP=your_server_ip
CONDUIT_SSH_USER=your_ssh_user
CONDUIT_DOMAIN=your_domain.com

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Database
CONDUIT_APP_DATABASE_PASSWORD=secure_database_password

# Email (Mailgun)
MAILGUN_API_KEY=your_mailgun_api_key
MAILGUN_DOMAIN=your_mailgun_domain
MAILGUN_SMTP_USERNAME=your_mailgun_smtp_username
MAILGUN_SMTP_PASSWORD=your_mailgun_smtp_password
MAILGUN_SIGNING_KEY=your_mailgun_signing_key

# Optional (if using Google Calendar/Drive)
GOOGLE_CALENDAR_ID=your_calendar_id
GOOGLE_DRIVE_FOLDER_ID=your_drive_folder_id
CALENDAR_CONFIG_CONTENT=base64_encoded_service_account_json
```

## Deployment Steps

### First-time Setup

1. Copy `.env.sample` to `.env` and fill in all required values:
   ```bash
   cp .env.sample .env
   # Edit .env with your values
   ```

2. Load environment variables:
   ```bash
   source .env
   ```

3. Initialize Kamal:
   ```bash
   kamal init
   ```

### Deploy

`.env.deploy` must export **every** variable that `.kamal/secrets` references — Kamal reads them
from the shell and will deploy empty strings without complaint. `bin/deploy-preflight` checks
that before anything ships:

```bash
. ./.env.deploy && bin/deploy-preflight && bundle exec kamal deploy
```

Or use the wrapper script, which runs the same preflight:

```bash
./deploy_with_stream.sh
```

This script will:
- Check that all required environment variables are set
- Validate Stream Chat credentials
- Build and deploy your application with Kamal

### Alternative: Manual Deployment

If you prefer to deploy manually:

```bash
# Ensure environment variables are loaded
source .env

# Deploy with Kamal
kamal deploy
```

### Post-Deployment

After successful deployment:

1. Your application will be available at: `https://your-domain.com`
2. Stream Chat interface (for testing) at: `https://your-domain.com/chat`
3. The chat is not visible in the navbar by default (development/testing only)

### Troubleshooting

#### Stream Chat not working?
- Verify STREAM_PROD_API_KEY and STREAM_PROD_API_SECRET in `.env` are the production app's (Stream dashboard → app → Overview)
- Confirm what the container is running: `kamal app exec --reuse 'printenv STREAM_API_KEY'`
- Check Rails logs: `kamal app logs`
- Test Stream connection: `kamal app exec 'bin/rails stream_chat:list_channels'`

#### Environment variables not being picked up?
- Ensure you've sourced your .env file: `source .env`
- Check Kamal secrets: `kamal env push`

#### Database connection issues?
- Verify CONDUIT_APP_DATABASE_PASSWORD is set
- Check PostgreSQL is running: `kamal accessory logs db`

### Updating Stream Chat Credentials

If you need to update Stream Chat credentials:

1. Update your `.env` file with new credentials
2. Source the updated file: `source .env`
3. Push new environment variables: `kamal env push`
4. Restart the app: `kamal app restart`

## Security Notes

- Never commit `.env` or `.kamal/secrets` to version control
- Keep your Stream Chat API Secret secure
- Regularly rotate your credentials
- Use strong passwords for database and services
## Backups

`NightlyBackupJob` runs every night at 10:15 UTC (about 3am Pacific) from
Solid Queue's recurring schedule. It writes to the private bucket
`gs://wide-gamma-462206-r8-backups` in the `wide-gamma-462206-r8` project:

* `db/conduit_app-<UTC time>.dump.enc` — a `pg_dump` of the main database
  (custom format), encrypted with `BACKUP_PASSPHRASE`. Kept 30 days.
* `files/…` — a mirror of `/rails/storage` (photos and other uploads). Only
  changed files are copied each night. The bucket keeps versioning on, so a
  deleted or overwritten file can still be restored for 30 days.

The cache, queue and cable databases hold nothing that needs a backup.

Sentry's cron monitor `nightly-backup` alerts if a night fails or doesn't
run. The job uses a service account, `conduit-backups@…`, which has rights to
this bucket only. Its key is `BACKUP_GCS_CREDENTIALS` (base64 JSON) in
`.env.deploy`.

**The passphrase isn't stored anywhere but `.env.deploy` and the server.**
Keep a copy in a password manager. Without it, the database dumps can't be
decrypted.

To run a backup now: `bundle exec kamal app exec --reuse 'bin/rails runner NightlyBackupJob.perform_now'`

### Restoring the database

```sh
. ./.env.deploy                       # BACKUP_PASSPHRASE
gcloud storage ls gs://wide-gamma-462206-r8-backups/db/   # pick a dump
gcloud storage cp gs://wide-gamma-462206-r8-backups/db/conduit_app-<time>.dump.enc .

# Decrypt (the same settings as DatabaseDump::DECRYPT)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
  -pass env:BACKUP_PASSPHRASE -in conduit_app-<time>.dump.enc -out conduit_app.dump

# Check it, then restore into an empty database (here a scratch one)
pg_restore --list conduit_app.dump | head
createdb conduit_restore_check
pg_restore --no-owner --no-privileges -d conduit_restore_check conduit_app.dump
```

To restore production itself: stop the app (`bundle exec kamal app stop`), copy the
decrypted dump to the server, restore it into the `db` accessory with
`pg_restore --clean --if-exists --no-owner -d conduit_app_production`, then
`bundle exec kamal app boot`.

### Restoring uploaded files

```sh
gcloud storage rsync -r gs://wide-gamma-462206-r8-backups/files/ ./storage-restore/
```

Then copy them into the `conduit_app_storage` volume on the server. To get
back a file deleted in the last 30 days, list its versions with
`gcloud storage ls -a gs://wide-gamma-462206-r8-backups/files/<path>`.
