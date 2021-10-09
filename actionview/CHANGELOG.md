*   Deprecate `:remote` option for `form_for` and `:local` option for `form_with`

    Also deprecate `config.action_view.embed_authenticity_token_in_remote_forms` and
    `config.action_view.form_with_generates_remote_forms` configurations.

    *Sean Doyle*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
