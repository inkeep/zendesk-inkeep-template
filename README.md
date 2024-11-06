This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Initial Setup

Before running the development server, you'll need to run the following scripts:

```bash
# Sets up initial configuration and dependencies
./setup.sh

# Verifies your environment is properly configured
./verify.sh

# Optional: Cleans up temporary files and caches
./cleanup.sh
```

### What these scripts do:

- `setup.sh`: Initializes the project by installing dependencies, setting up environment variables, and configuring necessary services.
- `verify.sh`: Checks that all required dependencies are installed and environment variables are properly set.
- `cleanup.sh`: Removes temporary files, clears caches, and resets the development environment to a clean state.

## Environment Variables

The following environment variables are required:

    ```bash
    ZENDESK_SUBDOMAIN=<your-subdomain> # e.g. if your Zendesk URL is mycompany.zendesk.com, enter 'mycompany'
    ZENDESK_API_TOKEN=<create an API token at https://support.zendesk.com/hc/en-us/articles/4408889192858-Generating-a-new-API-token>
    ZENDESK_API_USER=<email address of your zendesk user>
    ```

## Deploy on Vercel

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Finkeep%2Fzendesk-inkeep-template&env=ZENDESK_SUBDOMAIN,ZENDESK_API_TOKEN,ZENDESK_API_USER,INKEEP_API_KEY&project-name=zendesk-inkeep-responder-1&repository-name=zendesk-inkeep-responder-1)

Required environment variables for deployment:
- `DATABASE_URL`: Your PostgreSQL database connection string
- `AUTH_SECRET`: A secret key for authentication (min 32 characters)
- `GITHUB_CLIENT_ID`: OAuth client ID from GitHub
- `GITHUB_CLIENT_SECRET`: OAuth client secret from GitHub

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!
