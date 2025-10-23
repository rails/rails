*   Fix cross-browser rendering consistency for `include_blank` option in select helpers.

    Replace single space character with `&nbsp;` HTML entity in blank option labels
    to ensure consistent rendering across browsers, particularly Firefox.

    Affects `select`, `collection_select`, `time_zone_select`, and `select_tag` helpers.

    *Victor Cobos*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.