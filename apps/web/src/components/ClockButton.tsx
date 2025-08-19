import { useState } from 'react'
import { request } from '../lib/request'

export default function ClockButton() {
  const [msg, setMsg] = useState<string>('')

  async function onClick() {
    try {
      const data = await request('/api/clock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ts: Date.now() })
      })
      setMsg(JSON.stringify(data))
    } catch (e: any) {
      setMsg(`Error: ${e.message}`)
    }
  }

  return (
    <div style={{display:'grid', gap:8}}>
      <button onClick={onClick}>Clock</button>
      <pre>{msg}</pre>
    </div>
  )
}
