import { z } from "zod";

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
    authorId: z.string(),
    authorName: z.string(),
    messageContent: z.string(),
    timestamp: z.string().datetime()
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
  return Response.json({ message: "Hello, world!" });
};
