*   Add `config.action_cable.max_message_size` to limit the size of the messages a client can send.

    Action Cable built its WebSocket driver without a size limit, so websocket-driver's
    own applied: 64 MiB per message, buffered in full before Action Cable reads it.
    A message over the configured size now closes the connection with status 1009.
    The default is unchanged.

    ```ruby
    config.action_cable.max_message_size = 1.megabyte
    ```

    *Rafa Souza*

*   Filter parameters from the message logged when a command can't be handled.

    When a channel action raised, the error log included the raw WebSocket message,
    so values hidden by `filter_parameters` in the action's debug log were written
    in clear at the error level. The message, its identifier and its data are now
    filtered, and a message that can't be decoded or filtered is replaced by
    `[FILTERED]` and its size. The identifier and command quoted by subscription
    errors, and the identifier in the "Unsubscribing from channel" log, are
    filtered too.

    *Clément Joubert*

*   Close the connection when the event loop can't attach its socket.

    If `NIO::Selector#register` raised, as it does on JRuby for UNIX sockets,
    the stream was never closed and the client hung. The socket is now closed
    and the connection torn down. The socket is also closed when it can't be
    removed from the event loop.

    *Sampo Kuokkanen*

*   Process each connection's commands in the order the client sent them.

    Commands were handed to the worker pool independently, so two commands from
    one connection could run at the same time or out of order. When a client
    unsubscribed from a channel and subscribed to it again, as page navigations
    do, the subscribe could run first and be rejected as a duplicate, leaving the
    client without a subscription until it re-sent the command. A connection's
    work (opening, commands, stream callbacks, periodic timers and closing) now
    runs one at a time, in order, still on the worker pool's threads.

    *Sam Ruby*

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
