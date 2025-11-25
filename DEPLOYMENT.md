# Deployment Guide for ConduitApp with Stream Chat

## Prerequisites

1. Ensure you have all required environment variables set in your `.env` file
2. Have Docker and Kamal installed on your local machine
3. Have SSH access to your deployment server

## Environment Variables

### Required for Stream Chat

```bash
# Stream Chat Configuration (get from https://getstream.io/)
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret
```

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

### Deploy with Stream Chat

Use the provided deployment script that validates all required environment variables:

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
- Verify STREAM_API_KEY and STREAM_API_SECRET are correct
- Check Rails logs: `kamal app logs`
- Test Stream connection: `kamal app exec 'bin/rails stream:test'`

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