*   Allow configuring the Action Cable server implementation.

    `config.action_cable.server_class` can now be set to a server class. The
    configured server remains the `ActionCable.server` singleton and Rack
    endpoint, allowing alternative server implementations to provide the Action
    Cable runtime boundary without configuring internals of the default server.

    *Samuel Williams*

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
