*   Added verification of route constraints given as a Proc or an object responding
    to `:matches?`.  Previously, when given an non-complying object, it would just
    silently fail to enforce the constraint.  It will now raise an ArgumentError
    when setting up the routes.

    *Xavier Defrang*

*   Fix `Mime::Type.parse` when bad accepts header is looked up. Previously it
    was setting `request.formats` with an array containing a `nil` value, which
    raised an error when setting the controller formats.

    Fixes #10965

    *Becker*

*   Merge `:action` from routing scope and assign endpoint if both `:controller`
    and `:action` are present. The endpoint assignment only occurs if there is
    no `:to` present in the options hash so should only affect routes using the
    shorthand syntax (i.e. endpoint is inferred from the path).

    Fixes #9856

    *Yves Senn*, *Andrew White*

*   ActionView extracted from ActionPack

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

*   Fix removing trailing slash for mounted apps #3215

    *Piotr Sarnacki*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
