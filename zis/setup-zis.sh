#!/bin/bash

# Exit on any error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display error messages
error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to validate config values
validate_config() {
    local subdomain_regex="^[a-zA-Z0-9-]+$"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    local integration_regex="^[a-z0-9-_]+$"

    [[ -z "$ZENDESK_SUBDOMAIN" ]] && error "ZENDESK_SUBDOMAIN is required"
    [[ -z "$ZENDESK_ADMIN_EMAIL" ]] && error "ZENDESK_ADMIN_EMAIL is required"
    [[ -z "$ZENDESK_API_TOKEN" ]] && error "ZENDESK_API_TOKEN is required"
    [[ -z "$INTEGRATION_NAME" ]] && error "INTEGRATION_NAME is required"

    [[ $ZENDESK_SUBDOMAIN =~ $subdomain_regex ]] || error "Invalid ZENDESK_SUBDOMAIN format"
    [[ $ZENDESK_ADMIN_EMAIL =~ $email_regex ]] || error "Invalid ZENDESK_ADMIN_EMAIL format"
    [[ $INTEGRATION_NAME =~ $integration_regex ]] || error "Invalid INTEGRATION_NAME format"
}

# Check for required commands
command_exists curl || error "curl is not installed"
command_exists jq || error "jq is not installed"
command_exists sed || error "sed is not installed"

# Check if required files exist
CONFIG_FILE="zis-config.env"
BUNDLE_TEMPLATE="zis-bundle.template.json"
[[ ! -f "$CONFIG_FILE" ]] && error "Config file not found. Please copy zis-config.template.env to zis-config.env and fill in your values"
[[ ! -f "$BUNDLE_TEMPLATE" ]] && error "Bundle template not found. Please ensure zis-bundle.template.json exists"

# Load configuration
source "$CONFIG_FILE"

# Validate configuration
validate_config

# Create RequestBin endpoint
echo "Creating RequestBin endpoint..."
REQUESTBIN_RESPONSE=$(curl -s "https://pipedream.com/api/v1/sources/http" \
    -H "Content-Type: application/json" \
    -d '{"name":"Inkeep Autoresponder Endpoint"}')

EXTERNAL_TARGET_URL=$(echo "$REQUESTBIN_RESPONSE" | jq -r '.url')

if [ -z "$EXTERNAL_TARGET_URL" ]; then
    error "Failed to create RequestBin endpoint"
fi

echo "RequestBin endpoint created: $EXTERNAL_TARGET_URL"

# Register integration name
echo "Registering integration name..."
REGISTER_RESPONSE=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/$INTEGRATION_NAME" \
    -H "Content-Type: application/json" \
    -d '{"description": "Inkeep Autoresponder Integration"}' \
    -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
    -X POST)

if [ $? -ne 0 ]; then
    error "Failed to register integration name"
fi

# Create bundle file from template
echo "Creating bundle file..."
BUNDLE_FILE="inkeep_autoresponder_bundle.json"
cp "$BUNDLE_TEMPLATE" "$BUNDLE_FILE"

# Replace placeholders in the bundle
sed -i.bak "s|EXTERNAL_TARGET_URL_PLACEHOLDER|${EXTERNAL_TARGET_URL}|g" "$BUNDLE_FILE"
sed -i.bak "s|INTEGRATION_NAME_PLACEHOLDER|${INTEGRATION_NAME}|g" "$BUNDLE_FILE"
rm "${BUNDLE_FILE}.bak"

# Upload bundle
echo "Uploading ZIS bundle..."
UPLOAD_RESPONSE=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/$INTEGRATION_NAME/bundles" \
    -H "Content-Type: application/json" \
    -d @"$BUNDLE_FILE" \
    -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
    -X POST)

if [ $? -ne 0 ]; then
    error "Failed to upload bundle"
fi

# Install job spec
echo "Installing job spec..."
INSTALL_RESPONSE=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/job_specs/install?job_spec_name=zis:${INTEGRATION_NAME}:job_spec:handle-ticket-created-event" \
    -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
    -X POST)

if [ $? -ne 0 ]; then
    error "Failed to install job spec"
fi

echo "
ZIS integration setup complete!

Your integration details:
- Integration Name: $INTEGRATION_NAME
- External Target URL: $EXTERNAL_TARGET_URL

To test the integration:
1. Create a new ticket in Zendesk
2. Check the RequestBin dashboard at $EXTERNAL_TARGET_URL to see the webhook payload

For troubleshooting:
- Check the integrations log in Zendesk Admin Center under Apps and integrations > Integrations > Logs
"

chmod +x setup-zis.sh 