#!/bin/bash

# Check if .env file exists in parent directory
if [ ! -f "../.env" ]; then
    echo "Error: .env file not found in parent directory"
    exit 1
fi

# Load environment variables from .env file in parent directory
source "../.env"

# Check if required variables are set
if [ -z "$ZENDESK_API_USER" ] || [ -z "$ZENDESK_API_TOKEN" ]; then
    echo "Error: ZENDESK_API_USER and ZENDESK_API_TOKEN must be set in .env file"
    exit 1
fi

ZENDESK_SUBDOMAIN="d3v-inkeep" # replace with your subdomain if different

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first:"
    echo "  For Ubuntu/Debian: sudo apt-get install jq"
    echo "  For MacOS: brew install jq"
    exit 1
fi

# Check if AI_PROCESSING_ENDPOINT is set
if [ -z "$AI_PROCESSING_ENDPOINT" ]; then
    echo "Error: AI_PROCESSING_ENDPOINT must be set in .env file"
    exit 1
fi

# Check if AI_AGENT_EMAIL is set
if [ -z "$AI_AGENT_EMAIL" ]; then
    echo "Error: AI_AGENT_EMAIL must be set in .env file"
    exit 1
fi

# Generate random password for the agent
AGENT_PASSWORD=$(openssl rand -base64 12)

# Create agent JSON payload
agent_data=$(cat <<EOF
{
  "user": {
    "email": "$AI_AGENT_EMAIL",
    "name": "AI Support Agent",
    "role": "agent",
    "password": "$AGENT_PASSWORD"
  }
}
EOF
)

# Create the agent
agent_response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
  -X POST "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/users.json" \
  -H "Content-Type: application/json" \
  -d "$agent_data")

if ! echo "$agent_response" | jq -e '.user.id' > /dev/null; then
    echo "Error creating agent:"
    echo "$agent_response" | jq '.'
    exit 1
fi

echo "Agent created successfully!"
echo "Agent Email: $AI_AGENT_EMAIL"
echo "Agent Password: $AGENT_PASSWORD"
echo "Please save these credentials securely"

# Handle webhook creation/verification
if [ -n "$AI_RESPONDER_WEBHOOK_ID" ]; then
    # Verify existing webhook
    webhook_response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
      -X GET "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/webhooks/$AI_RESPONDER_WEBHOOK_ID.json")
    
    if ! echo "$webhook_response" | jq -e '.webhook.id' > /dev/null; then
        echo "Error: Provided webhook ID does not exist"
        exit 1
    fi
    echo "Using existing webhook with ID: $AI_RESPONDER_WEBHOOK_ID"
else
    # Create new webhook
    webhook_data=$(cat <<EOF
{
  "webhook": {
    "name": "AI Response Webhook",
    "endpoint": "$AI_PROCESSING_ENDPOINT",
    "http_method": "POST",
    "request_format": "json",
    "subscriptions": ["conditional_ticket_events"]
  }
}
EOF
)

    webhook_response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
      -X POST "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/webhooks.json" \
      -H "Content-Type: application/json" \
      -d "$webhook_data")

    if ! echo "$webhook_response" | jq -e '.webhook.id' > /dev/null; then
        echo "Error creating webhook:"
        echo "$webhook_response" | jq '.'
        exit 1
    fi
    
    AI_RESPONDER_WEBHOOK_ID=$(echo "$webhook_response" | jq -r '.webhook.id')
    echo "Webhook created successfully with ID: $AI_RESPONDER_WEBHOOK_ID"
fi

# Create the trigger JSON payload
trigger_data=$(cat <<EOF
{
  "trigger": {
    "title": "Send New Ticket to AI Processing",
    "active": true,
    "position": 0,
    "conditions": {
      "all": [
        {
          "field": "status",
          "operator": "is",
          "value": "new"
        },
        {
          "field": "update_type",
          "operator": "is",
          "value": "Create"
        }
      ]
    },
    "actions": [
      {
        "field": "notification_webhook",
        "value": [
          "$AI_PROCESSING_ENDPOINT",
          "{\"ticket_id\":\"\{\{ticket.id\}\}\",\"ticket_title\":\"\{\{ticket.title\}\}\",\"ticket_description\":\"\{\{ticket.description\}\}\"}"
        ]
      }
    ]
  }
}
EOF
)

# Make the API request to create the trigger
response=$(curl -s -u "$ZENDESK_API_USER/token:$ZENDESK_API_TOKEN" \
  -X POST "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/v2/triggers.json" \
  -H "Content-Type: application/json" \
  -d "$trigger_data")

# Check if the trigger was created successfully
if echo "$response" | jq -e '.trigger.id' > /dev/null; then
    echo "Trigger created successfully!"
    echo "Trigger ID: $(echo "$response" | jq '.trigger.id')"
else
    echo "Error creating trigger:"
    echo "$response" | jq '.'
    exit 1
fi