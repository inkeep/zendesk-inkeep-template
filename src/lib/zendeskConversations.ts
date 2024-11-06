import type { z } from 'zod';
import type { ProvideLinksToolSchema } from './intelligent-support/schemas';

const ZENDESK_API_BASE_URL = 'https://d3v-inkeep.zendesk.com/sc/v2';

const myHeaders = new Headers();
myHeaders.append('Content-Type', 'application/json');
myHeaders.append('Accept', 'application/json');
myHeaders.append(
  'Authorization',
  `Basic ${Buffer.from(`${process.env.ZENDESK_CONVERSATION_API_KEY_ID}:${process.env.ZENDESK_CONVERSATION_API_SECRET}`).toString('base64')}`,
);

export interface ZendeskMessage {
  id: string;
  received: string;
  author: {
    userId?: string;
    displayName?: string;
    avatarUrl?: string;
    type: 'user' | 'business';
  };
  content: {
    type: string;
    text: string;
  };
  source: {
    integrationId?: string;
    type: string;
  };
}

export const serializeLinks = (links: z.infer<typeof ProvideLinksToolSchema>['links'] | null | undefined) => {
  const introSourcesBlurb = 'Sources:';

  if (!links || links.length === 0) {
    // If links is null, undefined, or empty, return just the intro blurb
    return introSourcesBlurb;
  }

  // Deduplicate links
  const deduplicatedLinks = links.reduce(
    (accumulator, currentLink) => {
      // Ensure currentLink.url and currentLink.title are valid strings
      const currentUrl = currentLink.url;
      const currentTitle = currentLink.title ?? 'Untitled';

      // Skip links without a valid URL
      if (!currentUrl) {
        return accumulator;
      }

      // Check for existing link with the same URL
      const existingByUrl = accumulator.find(link => link.url === currentUrl);

      if (existingByUrl) {
        const existingTitle = existingByUrl.title ?? 'Untitled';
        // If same URL, keep the one with the shorter title
        if (currentTitle.length < existingTitle.length) {
          // Replace the existing link
          const index = accumulator.indexOf(existingByUrl);
          accumulator[index] = { ...currentLink, title: currentTitle };
        }
      } else {
        // Check for existing link with the same title
        const existingByTitle = accumulator.find(link => (link.title ?? 'Untitled') === currentTitle);

        if (existingByTitle) {
          // If same title, keep the one with the shorter URL
          if (currentUrl.length < existingByTitle.url.length) {
            // Replace the existing link
            const index = accumulator.indexOf(existingByTitle);
            accumulator[index] = { ...currentLink, title: currentTitle };
          }
        } else {
          // No duplicates, add the current link
          accumulator.push({ ...currentLink, title: currentTitle });
        }
      }

      return accumulator;
    },
    [] as NonNullable<typeof links>,
  );

  // Format the deduplicated links
  const sources = deduplicatedLinks
    .map(link => {
      const title = link.title ?? 'Untitled';
      const url = link.url;

      return `%[${title}](${url})`;
    })
    .join('\n');

  return [introSourcesBlurb, sources].join('\n');
};

export const getMessages = async (
  appId: string,
  conversationId: string,
  pageAfter?: string,
  pageSize = 50,
): Promise<{ messages: ZendeskMessage[]; meta: { hasMore: boolean } }> => {
  const url = new URL(`${ZENDESK_API_BASE_URL}/apps/${appId}/conversations/${conversationId}/messages`);

  if (pageAfter) {
    url.searchParams.append('page[after]', pageAfter);
  }
  url.searchParams.append('page[size]', pageSize.toString());

  const response = await fetch(url.toString(), {
    headers: myHeaders,
  });
  const data = await response.json();
  return data;
};

export const getAllMessages = async (
  appId: string,
  conversationId: string,
  pageSize = 50,
): Promise<ZendeskMessage[]> => {
  let allMessages: ZendeskMessage[] = [];

  let pageAfter: string | undefined;
  let hasMore = true;

  while (hasMore) {
    console.log('getting messages page', appId, conversationId, pageAfter, pageSize);
    const data = await getMessages(appId, conversationId, pageAfter, pageSize);
    allMessages = [...allMessages, ...data.messages];
    hasMore = data.meta.hasMore;

    if (hasMore && data.messages.length > 0) {
      pageAfter = data.messages[data.messages.length - 1].id;
    }
  }

  return allMessages;
};
