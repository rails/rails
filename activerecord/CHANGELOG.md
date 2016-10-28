*   Improved partial writes with HABTM and has many through associations
    to fire database query only if relation has been changed.

    Fixes #19663.

    *Mehmet Emin İNAÇ*

*   Deprecate passing arguments and block at the same time to
    `ActiveRecord::QueryMethods#select`.

    *Prathamesh Sonpatki*

*   Optimistic locking: Added ability update locking_column value.
    Ignore optimistic locking if update with new locking_column value.

    *bogdanvlviv*

*   Fixed: Optimistic locking does not work well with null in the database.

    Fixes #26024

    *bogdanvlviv*

*   Fixed support for case insensitive comparisons of `text` columns in
    PostgreSQL.

    *Edho Arief*

*   Serialize JSON attribute value `nil` as SQL `NULL`, not JSON `null`

    *Trung Duc Tran*

*   Return `true` from `update_attribute` when the value of the attribute
    to be updated is unchanged.

    Fixes #26593.

    *Prathamesh Sonpatki*

*   Always store errors details information with symbols.

    When the association is autosaved we were storing the details with
    string keys. This was creating inconsistency with other details that are
    added using the `Errors#add` method. It was also inconsistent with the
    `Errors#messages` storage.

    To fix this inconsistency we are always storing with symbols. This will
    cause a small breaking change because in those cases the details could
    be accessed as strings keys but now it can not.

    Fix #26499.

    *Rafael Mendonça França*, *Marcus Vieira*

*   Calling `touch` on a model using optimistic locking will now leave the model
    in a non-dirty state with no attribute changes.

    Fixes #26496.

    *Jakob Skjerning*

*   Using a mysql2 connection after it fails to reconnect will now have an error message
    saying the connection is closed rather than an undefined method error message.

    *Dylan Thacker-Smith*

*   PostgreSQL array columns will now respect the encoding of strings contained
    in the array.

    Fixes #26326.

    *Sean Griffin*

*   Inverse association instances will now be set before `after_find` or
    `after_initialize` callbacks are run.

    Fixes #26320.

    *Sean Griffin*

*   Remove unnecessarily association load when a `belongs_to` association has already been
    loaded then the foreign key is changed directly and the record saved.

    *James Coleman*

*   Remove standardized column types/arguments spaces in schema dump.

    *Tim Petricola*

*   Avoid loading records from database when they are already loaded using
    the `pluck` method on a collection.

    Fixes #25921.

    *Ryuta Kamizono*

*   Remove text default treated as an empty string in non-strict mode for
    consistency with other types.

    Strict mode controls how MySQL handles invalid or missing values in
    data-change statements such as INSERT or UPDATE. If strict mode is not
    in effect, MySQL inserts adjusted values for invalid or missing values
    and produces warnings.

        def test_mysql_not_null_defaults_non_strict
          using_strict(false) do
            with_mysql_not_null_table do |klass|
              record = klass.new
              assert_nil record.non_null_integer
              assert_nil record.non_null_string
              assert_nil record.non_null_text
              assert_nil record.non_null_blob

              record.save!
              record.reload

              assert_equal 0,  record.non_null_integer
              assert_equal "", record.non_null_string
              assert_equal "", record.non_null_text
              assert_equal "", record.non_null_blob
            end
          end
        end

    https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html#sql-mode-strict

    *Ryuta Kamizono*

*   Sqlite3 migrations to add a column to an existing table can now be
    successfully rolled back when the column was given and invalid column
    type.

    Fixes #26087

    *Travis O'Neill*

*   Deprecate `sanitize_conditions`. Use `sanitize_sql` instead.

    *Ryuta Kamizono*

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
