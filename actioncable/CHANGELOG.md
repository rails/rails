*   Make executor and WebSocket server configurable.

    You can provide a custom implementation of an executor (timers and async callbacks) or a WebSocket server (low-level WebSocket connections handling):

    ```ruby
    config.action_cable.executor = -> (server) { MyCustomNonThreadedExecutor.new(server, foo: "bar") }
    config.action_cable.websocket_server = -> (server) { MyCustomWebSocketHandler.new(server) }
    ```

    The `server` parameter provides a current `ActionCable::Server::Base` instance (which acts as an Action Cable application container).

    *Vladimir Dementyev*

*   Make heartbeat (ping) interval configurable via `config.action_cable.beat_interval`

    *Vladimir Dementyev*

*   Move `ActionCable::Server::Configuration` to `ActionCable::Configuration`.

    The old constant remains available as an alias.

    *Samuel Williams*

*   Respect calls to `#reject` in `before_subscribe` callbacks.

    It doesn't call `#subscribed` if a `before_subscribe` callback calls `#reject`.

    *Joshua Young*

*   Extract low-level Action Cable server responsibilities into `ActionCable::Server`
    abstractions.

    This refactoring separates socket handling, concurrency primitives, and
    other transport-specific behavior from application-level connections and
    channels. It makes Action Cable more flexible as a framework and opens the
    door to alternative server implementations without changing user-facing
    channel and connection code.

    *Vladimir Dementyev*

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
