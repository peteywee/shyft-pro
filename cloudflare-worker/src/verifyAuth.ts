// cloudflare-worker/src/verifyAuth.ts
// Minimal Firebase ID token verification for Workers using WebCrypto.
// Verifies signature and critical claims (aud, iss, exp).
// NOTE: For brevity, this fetches certs per call; cache in global state in production.

type JWTPayload = Record<string, any>;

const GOOGLE_CERTS_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

function base64UrlToUint8Array(b64url: string): Uint8Array {
  const pad = '='.repeat((4 - (b64url.length % 4)) % 4);
  const b64 = (b64url + pad).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(b64);
  const arr = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return arr;
}

function parseJwt(token: string) {
  const [h, p, s] = token.split('.');
  if (!h || !p || !s) throw new Error('Invalid JWT format');
  const header = JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(h)));
  const payload = JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(p)));
  const signature = base64UrlToUint8Array(s);
  return { header, payload, signature, signingInput: new TextEncoder().encode(`${h}.${p}`) };
}

async function importX509ToCryptoKey(pem: string): Promise<CryptoKey> {
  const b64 = pem.replace('-----BEGIN CERTIFICATE-----', '').replace('-----END CERTIFICATE-----', '').replace(/\s+/g, '');
  const der = base64UrlToUint8Array(b64.replace(/\+/g, '-').replace(/\//g, '_')); // convert to URL base64 then back
  return crypto.subtle.importKey('spki', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
}

export async function verifyFirebaseToken(idToken: string, projectId: string): Promise<JWTPayload> {
  const { header, payload, signature, signingInput } = parseJwt(idToken);
  if (header.alg !== 'RS256') throw new Error('Unexpected alg');

  // fetch certs and select by kid
  const res = await fetch(GOOGLE_CERTS_URL, { cf: { cacheTtl: 300, cacheEverything: true }});
  if (!res.ok) throw new Error('Failed to fetch Google certs');
  const certs = await res.json() as Record<string, string>;
  const pem = certs[header.kid];
  if (!pem) throw new Error('Unknown key id');

  const key = await importX509ToCryptoKey(pem);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, signature, signingInput);
  if (!valid) throw new Error('Invalid signature');

  // Validate standard claims
  const now = Math.floor(Date.now() / 1000);
  if (payload.aud !== projectId) throw new Error('Invalid aud');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Invalid iss');
  if (typeof payload.exp !== 'number' || payload.exp < now) throw new Error('Token expired');

  return payload;
}
