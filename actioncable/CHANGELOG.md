*   Remove deprecated `action_cable.js` file from `@rails/actioncable` package. The library should always be imported as `actioncable.js`.

    *Connor Shea*

## Rails 8.1.0.beta1 (September 04, 2025) ##

*   Allow passing composite channels to `ActionCable::Channel#stream_for` – e.g. `stream_for [ group, group.owner ]`

    *hey-leon*

*   Allow setting nil as subscription connection identifier for Redis.

    *Nguyen Nguyen*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actioncable/CHANGELOG.md) for previous changes.
