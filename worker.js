export default {
  async fetch(request, env) {
    const url = new URL(request.url)
    if (url.pathname === '/index.wasm') {
      // Forward conditional headers (If-None-Match) so the asset can 304,
      // but force identity so we get the raw stored gzip bytes.
      const fwd = new Headers(request.headers)
      fwd.set('Accept-Encoding', 'identity')
      const res = await env.ASSETS.fetch(new Request(url, { headers: fwd }))
      const headers = new Headers(res.headers)
      headers.set('Content-Type', 'application/wasm')
      headers.set('Content-Encoding', 'gzip')
      return new Response(res.body, {
        status: res.status,
        headers,
        encodeBody: 'manual',
      })
    }
    return env.ASSETS.fetch(request)
  },
}
