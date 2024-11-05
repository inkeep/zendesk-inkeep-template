import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    ZENDESK_SUBDOMAIN: z.string().min(1),
    ZENDESK_ADMIN_EMAIL: z.string().email(),
    ZENDESK_API_TOKEN: z.string().min(1),
    INTEGRATION_NAME: z.string().regex(/^[a-z0-9-_]+$/, {
      message: "Integration name must only contain lowercase letters, numbers, hyphens, and underscores",
    }),
    INKEEP_API_KEY: z.string().min(1),
  },
  client: {},
  runtimeEnv: {
    ZENDESK_SUBDOMAIN: process.env.ZENDESK_SUBDOMAIN, 
    ZENDESK_ADMIN_EMAIL: process.env.ZENDESK_ADMIN_EMAIL,
    ZENDESK_API_TOKEN: process.env.ZENDESK_API_TOKEN,
    INTEGRATION_NAME: process.env.INTEGRATION_NAME,
    INKEEP_API_KEY: process.env.INKEEP_API_KEY,
  },
}); 