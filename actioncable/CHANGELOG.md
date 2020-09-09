## Rails 5.2.4.4 (September 09, 2020) ##

*   No changes.


## Rails 5.2.4.3 (May 18, 2020) ##

*   No changes.


## Rails 5.2.4.1 (December 18, 2019) ##

*   No changes.


## Rails 5.2.4 (November 27, 2019) ##

*   No changes.


## Rails 5.2.3 (March 27, 2019) ##

*   No changes.


## Rails 5.2.2.1 (March 11, 2019) ##

*   No changes.


## Rails 5.2.2 (December 04, 2018) ##

*   No changes.


## Rails 5.2.1.1 (November 27, 2018) ##

*   No changes.


## Rails 5.2.1 (August 07, 2018) ##

*   No changes.


## Rails 5.2.0 (April 09, 2018) ##

*   Removed deprecated evented redis adapter.

    *Rafael Mendonça França*

*   Support redis-rb 4.0.

    *Jeremy Daer*

*   Hash long stream identifiers when using PostgreSQL adapter.

    PostgreSQL has a limit on identifiers length (63 chars, [docs](https://www.postgresql.org/docs/current/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS)).
    Provided fix minifies identifiers longer than 63 chars by hashing them with SHA1.

    Fixes #28751.

    *Vladimir Dementyev*

*   Action Cable's `redis` adapter allows for other common redis-rb options (`host`, `port`, `db`, `password`) in cable.yml.

    Previously, it accepts only a [redis:// url](https://www.iana.org/assignments/uri-schemes/prov/redis) as an option.
    While we can add all of these options to the `url` itself, it is not explicitly documented. This alternative setup
    is shown as the first example in the [Redis rubygem](https://github.com/redis/redis-rb#getting-started), which
    makes this set of options as sensible as using just the `url`.

    *Marc Rendl Ignacio*

Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actioncable/CHANGELOG.md) for previous changes.
