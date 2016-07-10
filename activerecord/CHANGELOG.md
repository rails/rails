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

*   PostgreSQL: Fix db:structure:load silent failure on SQL error.

    The command line flag `-v ON_ERROR_STOP=1` should be used
    when invoking `psql` to make sure errors are not suppressed.

    Example:

        psql -v ON_ERROR_STOP=1 -q -f awesome-file.sql my-app-db

    Fixes #23818.

    *Ralin Chimev*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
