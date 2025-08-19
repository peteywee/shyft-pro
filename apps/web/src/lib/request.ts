export async function request(path: string, init?: RequestInit) {
  const base = import.meta.env.VITE_API_BASE || ''
  const url = base ? `${base}${path}` : path
  const res = await fetch(url, init)
  const ctype = res.headers.get('content-type') || ''

  const text = await res.text() // read once
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText} — ${text.slice(0,200)}`)
  }
  if (ctype.includes('application/json')) {
    return JSON.parse(text)
  }
  throw new Error(`Expected JSON but got ${ctype}. Head: ${text.slice(0,120)}`)
}


