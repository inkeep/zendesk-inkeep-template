import { createOpenAI } from '@ai-sdk/openai';
import {
  type CoreMessage,
  type DeepPartial,
  streamObject,
  type UserContent,
  TypeValidationError,
  JSONParseError,
  generateText
} from 'ai';
import type { Message } from '@/types/chat';

export async function generateFirstReply(messages: Message[]): Promise<string> {


    const inkeepBaseURL = 'https://api.inkeep.ai/v1';
    const ikpModel = 'inkeep-context-expert';

    const openai = createOpenAI({
        apiKey: process.env.INKEEP_API_KEY,
        baseURL: inkeepBaseURL,
      });
  const systemPrompt = `You are a helpful AI assistant engaging in a conversation. 
Your responses should be:
- Clear and concise
- Professional yet friendly
- Focused on addressing the user's needs
- Written in markdown format when appropriate

Analyze the conversation history and provide a relevant, helpful response as an AI agent.
Make sure to inform the user that they should see if this response is helpful, but a human agent will be notified and will respond if needed.`;

  const formattedMessages = messages.map(msg => ({
    role: msg.authorId === 'ai' ? 'agent' : 'user',
    content: msg.messageContent,
    name: msg.authorName
  }));


  const serializedMessages = formattedMessages.map(msg => 
    `${msg.role}: ${msg.name} - ${msg.content}`
  ).join('\n');



  const response = await generateText({
    model: openai(ikpModel),
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: serializedMessages
      }
    ]
  });

  return response.text;
}
