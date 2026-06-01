*   Fix the PostgreSQL subscription adapter dropping broadcasts to long multibyte stream names.

    PostgreSQL identifiers are limited to 63 *bytes*, and the adapter hashes any
    name over that limit to avoid silent truncation. The length check was done on
    character count rather than byte size, so a multibyte stream name with 63 or
    fewer characters but more than 63 bytes was silently truncated by PostgreSQL.

    *Kenta Ishizaki*


## Rails 8.1.3 (March 24, 2026) ##

*   No changes.


## Rails 8.1.2.1 (March 23, 2026) ##

*   No changes.


## Rails 8.1.2 (January 08, 2026) ##

*   No changes.


## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

*   Allow passing composite channels to `ActionCable::Channel#stream_for` – e.g. `stream_for [ group, group.owner ]`

    *hey-leon*

*   Allow setting nil as subscription connection identifier for Redis.

    *Nguyen Nguyen*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actioncable/CHANGELOG.md) for previous changes.
