*   Buffer writes to websocket connections, to avoid blocking threads
    that could be doing more useful things.

    *Matthew Draper*, *Tinco Andringa*

*   Protect against concurrent writes to a websocket connection from
    multiple threads; the underlying OS write is not always threadsafe.

    *Tinco Andringa*

*   Close hijacked socket when connection is shut down.

    Fixes #25613.

    *Tinco Andringa*


## Rails 5.0.0 (June 30, 2016) ##

*   Fix development reloading support: new cable connections are now correctly
    dispatched to the reloaded channel class, instead of using a cached reference
    to the originally-loaded version.

    *Matthew Draper*

*   WebSocket protocol negotiation.

    Introduces an Action Cable protocol version that moves independently
    of and, hopefully, more slowly than Action Cable itself. Client sockets
    negotiate a protocol with the Cable server using WebSockets' native
    subprotocol support:
      * https://tools.ietf.org/html/rfc6455#section-1.9
      * https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#Subprotocols

    If they can't negotiate a compatible protocol (usually due to upgrading
    the Cable server with a browser still running old JavaScript) then the
    client knows to disconnect, cease retrying, and tell the app that it hit
    a protocol mismatch.

    This allows us to evolve the Action Cable message format, handshaking,
    pings, acknowledgements, and more without breaking older clients'
    expectations of server behavior.

    *Daniel Rhodes*

*   Pubsub: automatic stream decoding.

        stream_for @room, coder: ActiveSupport::JSON do |message|
          # `message` is a Ruby hash here instead of a JSON string

    The `coder` must respond to `#decode`. Defaults to `coder: nil`
    which skips decoding entirely.

    *Jeremy Daer*

*   Add ActiveSupport::Notifications to ActionCable::Channel.

    *Matthew Wear*

*   Safely support autoloading and class unloading, by preventing concurrent
    loads, and disconnecting all cables during reload.

    *Matthew Draper*

*   Ensure ActionCable behaves correctly for non-string queue names.

    *Jay Hayes*

*   Added `em_redis_connector` and `redis_connector` to
   `ActionCable::SubscriptionAdapter::EventedRedis` and added `redis_connector`
    to `ActionCable::SubscriptionAdapter::Redis`, so you can overwrite with your
    own initializers. This is used when you want to use different-than-standard
    Redis adapters, like for Makara distributed Redis.

    *DHH*

*   Support PostgreSQL pubsub adapter.

    *Jon Moss*

*   Remove EventMachine dependency.

    *Matthew Draper*

*   Remove Celluloid dependency.

    *Mike Perham*

*   Create notion of an `ActionCable::SubscriptionAdapter`.
    Separate out Redis functionality into
    `ActionCable::SubscriptionAdapter::Redis`, and add a
    PostgreSQL adapter as well. Configuration file for
    ActionCable was changed from`config/redis/cable.yml` to
    `config/cable.yml`.

    *Jon Moss*

*   Added to Rails!

    *DHH*
