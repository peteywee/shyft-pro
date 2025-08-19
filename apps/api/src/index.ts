import { Hono } from 'hono'

const app = new Hono()

// Healthcheck
app.get('/health', (c) => c.json({ ok: true, service: 'ryne-api' }))

// Example endpoint you're "clocking/pushing"
app.post('/api/clock', async (c) => {
  const body = await c.req.json().catch(() => null)
  if (!body) return c.json({ ok: false, error: 'invalid_json' }, 400)

  // do work here...
  return c.json({ ok: true, now: Date.now(), received: body })
})

// Always return JSON on server errors
app.onError((err, c) => {
  console.error(err)
  return c.json({ ok: false, error: 'internal_error' }, 500)
})

export default app
