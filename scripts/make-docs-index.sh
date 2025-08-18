#!/usr/bin/env bash
set -euo pipefail
mkdir -p site
cat > site/index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"/><title>Shyft Docs</title></head>
  <body style="font: 16px/1.5 system-ui, sans-serif; padding:24px;">
    <h1>Shyft Documentation</h1>
    <ul>
      <li><a href="./typedoc/client/index.html">Client Typedoc</a></li>
      <li><a href="./typedoc/server/index.html">Server Typedoc</a></li>
      <li><a href="./api/index.html">HTTP API (OpenAPI/Redoc)</a></li>
      <li><a href="https://github.com/top-shelf-service/ryne">Repository</a></li>
    </ul>
  </body>
</html>
HTML
