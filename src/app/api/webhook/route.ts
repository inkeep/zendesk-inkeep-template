import { z } from "zod";
import { createClient } from "node-zendesk";
import { generateQaModeResponse } from "@/lib/intelligent-support/support";
import type { ZendeskMessage } from "@/lib/zendeskConversations";

// Initialize Zendesk client
const client = createClient({
  username: process.env.ZENDESK_API_USER!,
  token: process.env.ZENDESK_API_TOKEN!,
  subdomain: process.env.ZENDESK_SUBDOMAIN!
});

export const POST = async (req: Request) => {
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Invalid JSON in request body" }),
      { status: 400 }
    );
  }

  const bodySchema = z.object({
    ticket_id: z.string().transform((val) => Number.parseInt(val, 10)),
    ticket_title: z.string(),
  });

  const result = bodySchema.safeParse(body);    
  
  if (!result.success) {
    return new Response(
      JSON.stringify({ 
        error: "Invalid request parameters",
        details: result.error.issues
      }),
      { status: 400 }
    );
  }

  const { ticket_id } = result.data;
  
  try {
    // Fetch ticket details and comments
    const [ticketResponse, commentsResponse] = await Promise.all([
      client.tickets.show(ticket_id),
      client.tickets.getComments(ticket_id)
    ]);

    // Get user and their organization details
    const requesterId = ticketResponse.result.requester_id;
    const [userDetailsResponse, userIdentitiesResponse] = await Promise.all([
      client.users.show(requesterId),
      client.useridentities.list(requesterId)
    ]);

    // If user belongs to an organization, fetch org details
    let orgDetails = null;
    if (userDetailsResponse.result.organization_id) {
      orgDetails = await client.organizations.show(userDetailsResponse.result.organization_id);
    }

    // Access user and org metadata
    const userMetadata = userDetailsResponse.result.user_fields;
    const {organization_fields, tags, notes, name} = orgDetails?.result ?? {};

    console.log('User Metadata:', userMetadata);
    console.log('Organization Metadata:', organization_fields, tags, notes, name);

    console.log(commentsResponse);

    // Create a cache for author details
    const authorCache = new Map<number, any>();
    
    // Get unique author IDs from comments
    const authorIds = [...new Set(commentsResponse.map(comment => comment.author_id))];
    
    // Fetch all unique authors in parallel
    console.log('Fetching authors...');
    await Promise.all(
      authorIds.map(async (authorId) => {
        const authorResponse = await client.users.show(authorId);
        authorCache.set(authorId, authorResponse.result);
      })
    );

    console.log('Author Cache:');
    console.dir(authorCache);

    const messages = commentsResponse.map<ZendeskMessage>((comment) => {
      const author = authorCache.get(comment.author_id);
      return {
        id: comment.id,
        received: comment.created_at,
        author: {
          type: author.role === 'end-user' ? 'user' : 'business',
          name: author.name,
          email: author.email,
        },
        content: {
          text: comment.body,
        },
        source: 'zendesk',
      };
    });

    const response = await generateQaModeResponse({ messages, metadata: {
      userMetadata,
      organizationMetadata: {organization_fields, tags, notes, name}
    }})


    if (response.aiAnnotations.answerConfidence === 'very_confident') {
       // First add the public comment
    await client.tickets.update(ticket_id, {
      ticket: {
        comment: {
          body: response.text,
          public: true,
        }
      }
      });
    } else {
      // Then add the internal note with metadata
      await client.tickets.update(ticket_id, {
        ticket: {
          comment: {
            body: `Internal Note\n\nUser Metadata: ${JSON.stringify(userMetadata, null, 2)}`,
            public: false,
          }
        }
      });
    }

    return Response.json({ 
      message: "Ticket processed",
      ticketId: ticket_id,
      ticketTitle: ticketResponse.result.subject,
      commentCount: commentsResponse.length,
      userMetadata,
      
    });

  } catch (error) {
    console.error('Zendesk API error:', error);
    return new Response(
      JSON.stringify({ 
        error: "Failed to process ticket with Zendesk API",
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500 }
    );
  }
};
