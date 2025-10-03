*   Fixes the `after_subscribe` callback to call after the subscription confirmation
    is transmitted or final-rejected, even when deferred for stream subscriptions.

    *Ben Sheldon*
## Rails 8.1.0.beta1 (September 04, 2025) ##

*   Allow passing composite channels to `ActionCable::Channel#stream_for` – e.g. `stream_for [ group, group.owner ]`

    *hey-leon*

*   Allow setting nil as subscription connection identifier for Redis.

    *Nguyen Nguyen*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actioncable/CHANGELOG.md) for previous changes.
