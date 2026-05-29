*   Make duplicate `subscribe` commands idempotent.

    When a client sends a `subscribe` command for an identifier it is already
    subscribed to, re-transmit `confirm_subscription` instead of raising
    `Subscriptions::AlreadySubscribedError`. The `subscribed` callback is not
    invoked a second time and no new subscription is registered. This
    addresses long-standing reports (#24875, #44652, #48292) where clients
    that legitimately re-issue subscribe commands (e.g. Turbo
    `<turbo-cable-stream-source>` across morph/refresh cycles, React/Vue
    components, reconnect loops) would either spin retrying because no
    confirmation arrived, or, more recently, crash the connection on the
    raised exception.

    The `Subscriptions::AlreadySubscribedError` class is removed; it was
    introduced in the unreleased adapterization refactor and never shipped.

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
