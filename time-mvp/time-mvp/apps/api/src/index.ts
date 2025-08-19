import { Hono } from 'hono';
import { z } from 'zod';

const app = new Hono();

// basic timing/logging
app.use('*', async (c, next) => {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  console.log(JSON.stringify({ path: c.req.path, status: c.res.status, ms }));
});

app.get('/health', c => c.json({ status: 'ok' }));

const PunchBody = z.object({
  type: z.enum(['IN','OUT']),
  siteId: z.string().optional(),
  tsDevice: z.string().optional(),
  idempotencyKey: z.string().optional()
});

app.post('/punch', async c => {
  const body = await c.req.json().catch(() => ({}));
  const parsed = PunchBody.safeParse(body);
  if (!parsed.success) return c.json({ error: 'Bad input' }, 400);
  return c.json({ id: 'stub', ts_server: new Date().toISOString() }, 201);
});

export default app;
