*   ActionCable's `redis` adapter allows for other common redis-rb options (`host`, `port`, `db`, `password`) in cable.yml.

    Previously, it accepts only a [redis:// url](https://www.iana.org/assignments/uri-schemes/prov/redis) as an option.
    While we can add all of these options to the `url` itself, it is not explicitly documented. This alternative setup
    is shown as the first example in the [Redis rubygem](https://github.com/redis/redis-rb#getting-started), which
    makes this set of options as sensible as using just the `url`.

    *Marc Rendl Ignacio*

*   ActionCable socket errors are now logged to the console

    Previously any socket errors were ignored and this made it hard to diagnose socket issues (e.g. as discussed in #28362).

    *Edward Poot*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actioncable/CHANGELOG.md) for previous changes.
