## Rails 6.0.0.alpha (Unreleased) ##

*   Fix finding dependencies for templates. No longer find dependencies inside
    of HTML tags and also calls to render that include a instantiating an object.

    Fixes #21951 and #23536

    *Daniel Fox*

*   Change translation key of `submit_tag` from `module_name_class_name` to `module_name/class_name`.

    *Rui Onodera*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionview/CHANGELOG.md) for previous changes.
