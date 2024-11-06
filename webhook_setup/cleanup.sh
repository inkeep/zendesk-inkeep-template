#!/bin/bash

echo "WARNING: This script will delete Zendesk resources from your instance."
echo "Resources that will be deleted:"
echo "- Webhook for Inkeep AI Response"
echo "- Trigger for sending new tickets to AI processing"
echo ""
echo "Please carefully review this script and consider the impact on your Zendesk environment before proceeding."
echo "This script comes with NO WARRANTY and you run it at your own risk."
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled"
    exit 1
fi
# Load environment variables
source ../.env

# Check if .zendesk-resources exists
if [ ! -f "../.zendesk-resources" ]; then
    echo "Error: .zendesk-resources file not found"
    exit 1
fi

# Validate required environment variables
missing_vars=()
if [ -z "$ZENDESK_API_USER" ]; then
    missing_vars+=("ZENDESK_API_USER")
fi
if [ -z "$ZENDESK_API_TOKEN" ]; then
    missing_vars+=("ZENDESK_API_TOKEN")
fi
if [ -z "$ZENDESK_SUBDOMAIN" ]; then
    missing_vars+=("ZENDESK_SUBDOMAIN")
fi

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Error: The following required environment variables are missing:"
    printf '%s\n' "${missing_vars[@]}"
    echo "Please ensure these variables are set in your .env file"
    exit 1
fi

# Read and process each line from .zendesk-resources
while IFS='=' read -r key value; do
    # Skip empty lines
    [ -z "$key" ] && continue
    echo "Processing resource: $key"
    case "$key" in
        "WEBHOOK_ID")
            echo "Deleting webhook with ID: $value"
            response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
                -X DELETE "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/webhooks/$value")
            if [ -z "$response" ]; then
                echo "Successfully deleted webhook"
            else
                echo "Error deleting webhook: $response"
            fi
            ;;
            
        "TRIGGER_ID")
            echo "Deleting trigger with ID: $value"
            response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
                -X DELETE "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/triggers/$value.json")
            if [ -z "$response" ]; then
                echo "Successfully deleted trigger"
            else
                echo "Error deleting trigger: $response"
            fi
            ;;
            
        *)
            echo "Unknown resource type: $key"
            ;;
    esac
done < "../.zendesk-resources"

# Remove the resources file after cleanup
rm "../.zendesk-resources"
echo "Cleanup completed"

