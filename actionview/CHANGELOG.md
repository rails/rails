## Rails 6.0.0.alpha (Unreleased) ##

*   Don't enforce UTF-8 by default

    With the disabling of TLS 1.0 by most major websites, continuing to run
    IE8 or lower becomes increasingly difficult so default to not enforcing
    UTF-8 encoding as it's not relevant to other browsers.

    *Andrew White*

*   Change translation key of `submit_tag` from `module_name_class_name` to `module_name/class_name`.

    *Rui Onodera*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionview/CHANGELOG.md) for previous changes.
