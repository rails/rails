*   Detect half-open Action Cable connections via a ping/pong heartbeat.

    A new protocol revision, `actioncable-v1.1-json`, has the client respond
    to server heartbeat pings with a pong. If no pong (or any other message)
    arrives within two heartbeats, the server force-closes the connection
    instead of letting it linger for up to half an hour.

    Round-trip latency is emitted as the `connection_latency.action_cable`
    Active Support notification.

    *Stanko Krtalić Rusendić*

*   Fix Action Cable origin check to respect `X-Forwarded-Host` behind reverse proxies.

    The `allow_same_origin_as_host` check previously compared against the raw
    `HTTP_HOST` header, which fails when a proxy forwards requests with a
    different internal host. It now uses `request.host_with_port`, consistent
    with the rest of Rails.

    *Jordan Brough*

*   Channel generator now detects which JS package manager to use when
    installing javascript dependencies.

    *David Lowenfels*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actioncable/CHANGELOG.md) for previous changes.
