// cloudflare-worker/src/index.ts
import { verifyFirebaseToken } from './verifyAuth';

export interface Env {
  FIREBASE_PROJECT_ID: string;
  OPENAI_API_KEY: string;
}

async function json(req: Request) {
  try { return await req.json(); } catch { return null; }
}

async function handleSchedule(req: Request, env: Env) {
  const authHeader = req.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 });
  const token = authHeader.substring(7);

  let payload: any;
  try {
    payload = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
  } catch (err: any) {
    return new Response(`Unauthorized: ${err.message}`, { status: 401 });
  }

  if (payload.role !== 'Admin') return new Response('Forbidden', { status: 403 });

  const body = await json(req);
  if (!body) return new Response('Bad Request', { status: 400 });

  // Example: call OpenAI (or your AI provider) securely
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a schedule assistant.' },
        { role: 'user', content: `Make a schedule with constraints: ${JSON.stringify(body)}` }
      ],
    }),
  });

  if (!r.ok) {
    const t = await r.text();
    return new Response(`AI error: ${t}`, { status: 502 });
  }

  const out = await r.json();
  return new Response(JSON.stringify(out), { status: 200, headers: { 'Content-Type': 'application/json' } });
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (req.method === 'POST' && url.pathname === '/api/schedule') {
      return handleSchedule(req, env);
    }
    return new Response('Not Found', { status: 404 });
  }
};
