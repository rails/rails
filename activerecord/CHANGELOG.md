*   Option to remove standardized column types/arguments spaces in schema dump
    with `ActiveRecord::SchemaDumper.standardized_argument_widths` and
    `ActiveRecord::SchemaDumper.standardized_type_widths` methods.

    *Tim Petricola*

*   Doing count on relations that contain LEFT OUTER JOIN Arel node no longer
    force a DISTINCT. This solves issues when using count after a left_joins.

    *Maxime Handfield Lapointe*

*   RecordNotFound raised by association.find exposes `id`, `primary_key` and
    `model` methods to be consistent with RecordNotFound raised by Record.find.

    *Michel Pigassou*

*   Hashes can once again be passed to setters of `composed_of`, if all of the
    mapping methods are methods implemented on `Hash`.

    Fixes #25978.

    *Sean Griffin*

*   Fix the SELECT statement in `#table_comment` for MySQL.

    *Takeshi Akima*

*   Virtual attributes will no longer raise when read on models loaded from the
    database

    *Sean Griffin*

*   Support calling the method `merge` in `scope`'s lambda.

    *Yasuhiro Sugino*

*   Fixes multi-parameter attributes conversion with invalid params.

    *Hiroyuki Ishii*

*   Add newline between each migration in `structure.sql`.

    Keeps schema migration inserts as a single commit, but allows for easier
    git diffing.

    Fixes #25504.

    *Grey Baker*, *Norberto Lopes*

*   The flag `error_on_ignored_order_or_limit` has been deprecated in favor of
    the current `error_on_ignored_order`.

    *Xavier Noria*

*   Batch processing methods support `limit`:

        Post.limit(10_000).find_each do |post|
          # ...
        end

    It also works in `find_in_batches` and `in_batches`.

    *Xavier Noria*

*   Using `group` with an attribute that has a custom type will properly cast
    the hash keys after calling a calculation method like `count`.

    Fixes #25595.

    *Sean Griffin*

*   Fix the generated `#to_param` method to use `omission: ''` so that
    the resulting output is actually up to 20 characters, not
    effectively 17 to leave room for the default "...".
    Also call `#parameterize` before `#truncate` and make the
    `separator: /-/` to maximize the information included in the
    output.

    Fixes #23635.

    *Rob Biedenharn*

*   Ensure concurrent invocations of the connection reaper cannot allocate the
    same connection to two threads.

    Fixes #25585.

    *Matthew Draper*

*   Inspecting an object with an associated array of over 10 elements no longer
    truncates the array, preventing `inspect` from looping infinitely in some
    cases.

    *Kevin McPhillips*

*   Removed the unused methods `ActiveRecord::Base.connection_id` and
    `ActiveRecord::Base.connection_id=`.

    *Sean Griffin*

*   Ensure hashes can be assigned to attributes created using `composed_of`.

    Fixes #25210.

    *Sean Griffin*

*   Fix logging edge case where if an attribute was of the binary type and
    was provided as a Hash.

    *Jon Moss*

*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   Introduce `ActiveRecord::TransactionSerializationError` for catching
    transaction serialization failures or deadlocks.

    *Erol Fornoles*

*   PostgreSQL: Fix `db:structure:load` silent failure on SQL error.

    The command line flag `-v ON_ERROR_STOP=1` should be used
    when invoking `psql` to make sure errors are not suppressed.

    Example:

        psql -v ON_ERROR_STOP=1 -q -f awesome-file.sql my-app-db

    Fixes #23818.

    *Ralin Chimev*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
