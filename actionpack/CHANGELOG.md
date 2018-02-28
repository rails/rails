*   Include child session assertion count in ActionDispatch::IntegrationTest

    `IntegrationTest#open_session` uses `dup` to create the new session, which
    meant it had its own copy of `@assertions`. This prevented the assertions
    from being correctly counted and reported.

    Child sessions now have their `attr_accessor` overriden to delegate to the
    root session.

    Fixes #32142

    *Sam Bostock*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.
