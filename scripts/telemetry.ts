import { configDotenv } from "dotenv";

const POSTHOG_PROJECT_API_KEY = 'phc_tmyI0UQGFnLiRkVseDcCpO2vJmB1fuq8UI8XB2tmCU4';
const POSTHOG_API_HOST = 'https://app.posthog.com';

const template = 'zendesk-inkeep-template';

configDotenv();

async function sendTelemetryEvent() {
  if (process.env.INKEEP_TELEMETRY_DISABLED === 'true') {
    return;
  }

  console.log('\x1b[33m%s\x1b[0m', 'Sending anonymous telemetry event to Inkeep. To disable, set INKEEP_TELEMETRY_DISABLED=true\n\n');

  try {
    const distinctId = Math.random().toString(36).substring(2);
    
    await fetch(`${POSTHOG_API_HOST}/capture/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        api_key: POSTHOG_PROJECT_API_KEY,
        event: 'template_build',
        distinct_id: distinctId,
        properties: {
          template
        }
      })
    });
  } catch (error) {
    console.error('Failed to send telemetry:', error);
  }
}

sendTelemetryEvent(); 