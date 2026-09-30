# nghttp2

nghttp2 is the reference HTTP/2 implementation in C: the protocol state
machine (RFC 9113), HPACK header compression, and the framing layer. curl
and many servers link it, and it is the piece to reach for when you are
writing or reading HTTP/2 by hand rather than going through a full HTTP
library.

The API is a session with an explicit connection: you receive data from
your socket, feed it to `nghttp2_session_recv`, and nghttp2 tells you which
bytes to send and which frames to emit.

```c
nghttp2_session *session;
nghttp2_session_callbacks_new(&callbacks);
nghttp2_session_client_new(&session, client, callbacks, &settings, NULL);

nghttp2_submit_request(session, NULL, stream_id, &iv, &nv, NULL);
nghttp2_session_mem_recv(session, &readlen, in, 0);

ssize_t n = nghttp2_session_send(session, out, sizeof out);   /* write n bytes */
```

Callbacks are where the work happens: `on_frame_recv`, `on_data_chunk_recv`,
`on_stream_open`, `on_header`. Data is delivered in chunks, so a body
arrives incrementally rather than as one buffer.

Flow control is not automatic: `nghttp2_local_flow_control` tells you how
much the peer allows, and if you ignore it the session stalls.

## What retrolunar builds

A static `libnghttp2.a`, `nghttp2/nghttp2.h` and `nghttp2/nghttp2ver.h`, and
`libnghttp2.pc`. The applications (`nghttp`, `nghttpd`, `nghttpx`), the
examples, the tests and the Python/Rust bindings are off: host programs.
Optional dependencies are all off too, so the library keeps its dependency
surface at libc plus the system pthreads.

## Using it

```sh
pkg-config --cflags --libs libnghttp2
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the recipe
  adds only package facts: static, `-fpic`, everything optional off.
- This build has no TLS backend, which is the usual split: nghttp2 moves
  bytes, the TLS library underneath moves them securely. nghttp2 is often
  used with a separate HTTP library that provides both.
- HPACK tables are per session. Reusing a session across connections is
  fine; copying a session mid-stream is not.
