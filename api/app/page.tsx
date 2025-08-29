export default function Home() {
  return (
    <main className="p-8">
      <h1 className="text-2xl font-semibold">Ryne • Home</h1>
      <p className="mt-2 text-sm text-neutral-600">
        This page always renders. <a className="underline" href="/login">Sign in</a>.
      </p>
      <ul className="mt-4 list-disc pl-6 text-sm">
        <li><a className="underline" href="/api/health">/api/health</a> (Next health)</li>
        <li><a className="underline" href="/api/debug/cookies">/api/debug/cookies</a> (cookie debug)</li>
      </ul>
    </main>
  );
}
