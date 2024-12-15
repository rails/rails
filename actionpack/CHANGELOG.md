*   A route pointing to a non-existing controller now returns a 500 instead of a 404.

    A controller not existing isn't a routing error that should result
    in a 404, but a programming error that should result in a 500 and
    be reported.

    Until recently, this was hard to untangle because of the support
    for dynamic `:controller` segment in routes, but since this is
    deprecated and will be removed in Rails 8.1, we can now easily
    not consider missing controllers as routing errors.

    *Jean Boussier*

*   Add `check_collisions` option to `ActionDispatch::Session::CacheStore`.

    Newly generated session ids use 128 bits of randomness, which is more than
    enough to ensure collisions can't happen, but if you need to harden sessions
    even more, you can enable this option to check in the session store that the id
    is indeed free you can enable that option. This however incurs an extra write
    on session creation.

    *Shia*

*   In ExceptionWrapper, match backtrace lines with built templates more often,
    allowing improved highlighting of errors within do-end blocks in templates.
    Fix for Ruby 3.4 to match new method labels in backtrace.

    *Martin Emde*

*   Allow setting content type with a symbol of the Mime type.

    ```ruby
    # Before
    response.content_type = "text/html"

    # After
    response.content_type = :html
    ```

    *Petrik de Heus*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionpack/CHANGELOG.md) for previous changes.
