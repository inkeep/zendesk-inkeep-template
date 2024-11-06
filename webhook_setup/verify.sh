#!/bin/bash

# Check if .env file exists in parent directory
if [ ! -f "../.env" ]; then
    echo "Error: .env file not found in parent directory"
    exit 1
fi

# Load environment variables from .env file in parent directory
source "../.env"

# Check if required variables are set
if [ -z "$ZENDESK_API_USER" ] || [ -z "$ZENDESK_API_TOKEN" ] || [ -z "$AI_PROCESSING_ENDPOINT" ]; then
    echo "Error: ZENDESK_API_USER, ZENDESK_API_TOKEN, and AI_PROCESSING_ENDPOINT must be set in .env file"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first:"
    echo "  For Ubuntu/Debian: sudo apt-get install jq"
    echo "  For MacOS: brew install jq"
    exit 1
fi

# First, get all webhooks
echo "Fetching webhooks..."
webhooks_response=$(curl -s -i -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
  -X GET "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/webhooks")

# Echo full response for debugging
echo "Full Response:"
echo "$webhooks_response"

# Check HTTP status code
http_status=$(echo "$webhooks_response" | head -n 1 | cut -d' ' -f2)

if [ "$http_status" != "200" ]; then
    echo "Error: Failed to fetch webhooks. Status code: $http_status"
    echo "Response:"
    echo "$webhooks_response"
    echo "Please verify:"
    echo "1. Your ZENDESK_SUBDOMAIN is correct: $ZENDESK_SUBDOMAIN"
    echo "2. Your API credentials are correct"
    echo "3. You have the necessary permissions to access webhooks"
    exit 1
fi

# Extract JSON body (skip headers) - improved version
json_response=$(echo "$webhooks_response" | sed -n '/^{/,$p')

# Debug webhook response
echo "Debug - Webhook Response:"
echo "$json_response" | jq '.' || echo "Failed to parse JSON response"

# Check if our endpoint exists as a webhook (fixed to handle proper Zendesk response structure)
matching_webhook=$(echo "$json_response" | jq --arg endpoint "$AI_PROCESSING_ENDPOINT" '.webhooks[] | select(.endpoint == $endpoint)')

if [ -z "$matching_webhook" ]; then
    echo "No webhook found with endpoint: $AI_PROCESSING_ENDPOINT"
    exit 1
else
    webhook_id=$(echo "$matching_webhook" | jq -r '.id')
    echo "Found webhook with ID: $webhook_id"
fi

# Get all active triggers
echo "Fetching triggers..."
triggers_response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
  -X GET "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/triggers/active.json")

# Echo raw response
echo "Raw Triggers Response:"
echo "$triggers_response"

# Extract and validate JSON
echo -e "\nParsed Triggers JSON:"
echo "$triggers_response" | jq '.' || echo "Failed to parse triggers JSON response"

# Check for triggers using our webhook
echo "Checking for webhook-trigger pairs..."
matching_triggers=$(echo "$triggers_response" | jq --arg webhook_id "$webhook_id" '
  .triggers[] | 
  select(.actions[] | 
    select(.field == "notification_webhook" and .value[0] == $webhook_id)
  )')

if [ -z "$matching_triggers" ]; then
    echo "No triggers found connected to webhook ID: $webhook_id"
    exit 1
else
    echo "Found the following webhook-trigger pairs:"
    echo "Webhook ID: $webhook_id"
    echo "Connected triggers:"
    echo "$matching_triggers" | jq -r '["Title:", .title, "\nID:", .id, "\nDescription:", .description] | join(" ")'
    echo "Webhook and trigger(s) are properly connected!"
    exit 0
fi
