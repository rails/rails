*   Fixed a problem where the default options for the `button_tag` helper is not
    applied correctly.

    Fixes #14254.

    *Sergey Prikhodko*

*   Take variants into account when calculating template digests in ActionView::Digestor.

    The arguments to ActionView::Digestor#digest are now being passed as a hash
    to support variants and allow more flexibility in the future. The support for
    regular (required) arguments is deprecated and will be removed in Rails 5.0 or later.

    *Piotr Chmolowski, Łukasz Strzałkowski*


Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionview/CHANGELOG.md) for previous changes.
