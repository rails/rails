*   ActionCable's allowed_request_origins includes private IPs during development

    By default when in development, Action Cable's allowed_request_origins
    includes http://localhost:3000.  Because it is compelling to run

      rails s -b 0.0.0.0

    in development to experiment with Action Cable applications using
    multiple machines, we find all _private_ IPv4 addresses and add them
    into allowed_request_origins.  (No public Internet IP addresses, and
    do nothing in test and production environments.)

    *Lorin Thwaits*

*   Protect against concurrent writes to a websocket connection from
    multiple threads; the underlying OS write is not always threadsafe.

    *Tinco Andringa*

*   Add ActiveSupport::Notifications hook to Broadcaster#broadcast

    *Matthew Wear*

*   Close hijacked socket when connection is shut down.

    Fixes #25613.

    *Tinco Andringa*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md) for previous changes.
