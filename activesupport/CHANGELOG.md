*   Make the order of read_multi and write_multi notifications for `Cache::Store#fetch_multi` operations match the order they are executed in.

    *Adam Renberg Tamm*

*   Make return values of `Cache::Store#write` consistent.

    The return value was not specified before. Now it returns `true` on a successful write,
    `nil` if there was an error talking to the cache backend, and `false` if the write failed
    for another reason (e.g. the key already exists and `unless_exist: true` was passed).

    *Sander Verdonschot*

*   Fix logged cache keys not always matching actual key used by cache action.

    *Hartley McGuire*

*   Improve error messages of `assert_changes` and `assert_no_changes`

    `assert_changes` error messages now display objects with `.inspect` to make it easier
    to differentiate nil from empty strings, strings from symbols, etc.
    `assert_no_changes` error messages now surface the actual value.

    *pcreux*

*   Fix `#to_fs(:human_size)` to correctly work with negative numbers.

    *Earlopain*

*   Fix `BroadcastLogger#dup` so that it duplicates the logger's `broadcasts`.

    *Andrew Novoselac*

*   Fix issue where `bootstrap.rb` overwrites the `level` of a `BroadcastLogger`'s `broadcasts`.

    *Andrew Novoselac*

*   Fix compatibility with the `semantic_logger` gem.

    The `semantic_logger` gem doesn't behave exactly like stdlib logger in that
    `SemanticLogger#level` returns a Symbol while stdlib `Logger#level` returns an Integer.

    This caused the various `LogSubscriber` classes in Rails to break when assigned a
    `SemanticLogger` instance.

    *Jean Boussier*, *ojab*

*   Fix MemoryStore to prevent race conditions when incrementing or decrementing.

    *Pierre Jambet*

*   Implement `HashWithIndifferentAccess#to_proc`.

    Previously, calling `#to_proc` on `HashWithIndifferentAccess` object used inherited `#to_proc`
    method from the `Hash` class, which was not able to access values using indifferent keys.

    *fatkodima*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activesupport/CHANGELOG.md) for previous changes.
