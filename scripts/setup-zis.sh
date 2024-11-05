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

# Validate configuration from environment variables
validate_config

# Function to check if integration exists
check_integration_exists() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/$INTEGRATION_NAME" \
        -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN")
    
    [ "$status_code" -eq 200 ]
}

# Function to create or update integration
create_or_update_integration() {
    local method="POST"
    if check_integration_exists; then
        method="PUT"
        echo "Integration exists, updating..."
    else
        echo "Creating new integration..."
    fi

    local response=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/$INTEGRATION_NAME" \
        -H "Content-Type: application/json" \
        -d '{"description": "Inkeep Autoresponder Integration"}' \
        -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
        -X "$method")

    if [ $? -ne 0 ]; then
        error "Failed to create/update integration"
    fi
}

# Create bundle from template
create_bundle() {
    # Use the webhook URL from Vercel deployment
    local WEBHOOK_URL="https://${VERCEL_URL}/api/webhook"
    
    # Create bundle JSON with the webhook URL
    cat > "inkeep_autoresponder_bundle.json" << EOL
{
  "name": "Inkeep Autoresponder",
  "description": "Posts ticket data to external webhook endpoint",
  "zis_template_version": "2019-10-14",
  "resources": {
    "action_post_ticket_data": {
      "type": "ZIS::Action::Http",
      "properties": {
        "name": "action_post_ticket_data",
        "definition": {
          "method": "POST",
          "url": "${WEBHOOK_URL}",
          "headers": [
            {
              "key": "X-Zendesk-Ticket-Id",
              "value.\$": "\$.ticketId"
            }
          ],
          "requestBody": {
            "data": {
              "status.\$": "\$.ticketStatus",
              "priority.\$": "\$.ticketPriority"
            }
          }
        }
      }
    },
    "flow_ticket_created": {
      "type": "ZIS::Flow",
      "properties": {
        "name": "ticket-created-flow",
        "definition": {
          "StartAt": "ZendeskTicketCreated",
          "States": {
            "ZendeskTicketCreated": {
              "Type": "Action",
              "ActionName": "zis:${INTEGRATION_NAME}:action:action_post_ticket_data",
              "Parameters": {
                "ticketId.\$": "\$.input.ticket_event.ticket.id",
                "ticketStatus.\$": "\$.input.ticket_event.ticket.status",
                "ticketPriority.\$": "\$.input.ticket_event.ticket.priority"
              },
              "End": true
            }
          }
        }
      }
    },
    "jobspec_handle_ticket_event": {
      "type": "ZIS::JobSpec",
      "properties": {
        "name": "handle-ticket-created-event",
        "event_source": "support",
        "event_type": "ticket.TicketCreated",
        "flow_name": "zis:${INTEGRATION_NAME}:flow:ticket-created-flow"
      }
    }
  }
}
EOL
}

# Upload bundle
upload_bundle() {
    echo "Uploading ZIS bundle..."
    local response=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/$INTEGRATION_NAME/bundles" \
        -H "Content-Type: application/json" \
        -d @"inkeep_autoresponder_bundle.json" \
        -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
        -X POST)

    if [ $? -ne 0 ]; then
        error "Failed to upload bundle"
    fi
}

# Install or update job spec
install_job_spec() {
    echo "Installing/updating job spec..."
    local response=$(curl -s "https://$ZENDESK_SUBDOMAIN.zendesk.com/api/services/zis/registry/job_specs/install?job_spec_name=zis:${INTEGRATION_NAME}:job_spec:handle-ticket-created-event" \
        -u "$ZENDESK_ADMIN_EMAIL/token:$ZENDESK_API_TOKEN" \
        -X POST)

    if [ $? -ne 0 ]; then
        error "Failed to install job spec"
    fi
}

# Main execution
create_or_update_integration
create_bundle
upload_bundle
install_job_spec

echo "
ZIS integration setup complete!

Your integration details:
- Integration Name: $INTEGRATION_NAME
- Webhook URL: https://${VERCEL_URL}/api/webhook

The integration is now configured to send ticket events to your webhook endpoint.
" 