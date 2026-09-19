#!/bin/bash

# Deploy script for Kamal with Stream Chat environment variables
# Usage: ./deploy_with_stream.sh

echo "🚀 Deploying ConduitApp with Stream Chat integration..."

# Check if Stream environment variables are set
# Production deploys ship STREAM_PROD_* (see .kamal/secrets). The bare STREAM_* pair is local dev.
if [ -z "$STREAM_PROD_API_KEY" ] || [ -z "$STREAM_PROD_API_SECRET" ]; then
    echo "❌ Error: Stream Chat production credentials not found!"
    echo ""
    echo "Please set the following environment variables:"
    echo "  export STREAM_PROD_API_KEY=your_production_stream_api_key"
    echo "  export STREAM_PROD_API_SECRET=your_production_stream_api_secret"
    echo ""
    echo "You can add these to your .env file or shell profile"
    exit 1
fi

echo "✅ Stream Chat production credentials found"
echo "  API Key: ${STREAM_PROD_API_KEY:0:10}..."

# Check if other required environment variables are set
required_vars=(
    "DOCKER_USERNAME"
    "CONDUIT_SERVER_IP"
    "CONDUIT_SSH_USER"
    "CONDUIT_DOMAIN"
    "KAMAL_REGISTRY_PASSWORD"
    "GOOGLE_CLIENT_ID"
    "GOOGLE_CLIENT_SECRET"
    "CONDUIT_APP_DATABASE_PASSWORD"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=($var)
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "❌ Error: Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please ensure all required variables are set in your .env file"
    exit 1
fi

echo "✅ All required environment variables are set"

# Deploy with Kamal
echo ""
echo "📦 Building and deploying with Kamal..."
kamal deploy

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Your Stream Chat integration is now live at: https://$CONDUIT_DOMAIN/chat"
echo ""
echo "Note: Stream Chat is currently accessible via direct URL only (not in navbar)"