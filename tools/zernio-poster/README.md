# Zernio Poster

Save several Zernio API keys, one per set of connected accounts, and post a video to any mix of their accounts at once. It's a single file with no dependencies and needs Node 18 or later.

```sh
node tools/zernio-poster/zernio-poster.mjs     # then open http://localhost:4747
```

Keys are stored in `~/.zernio-poster/keys.json`, and only your user can read that file. The server listens on localhost only, and the page shows each key masked.

## Connect Claude Code

```sh
claude mcp add zernio -- node /full/path/to/tools/zernio-poster/zernio-poster.mjs mcp
```

Claude then gets two tools:
- `list_accounts`: lists the accounts on every saved key.
- `post_video`: takes a local file path, a caption, an optional YouTube title and schedule, and account ids. It uploads the video and posts it.

## Notes

- The default API address is `https://zernio.com/api/v1`. Set `ZERNIO_BASE_URL` if yours differs.
- Posting uses `GET /accounts`, `POST /media/presign` and `POST /posts`. If Zernio rejects a field, the error shows up in the result.
