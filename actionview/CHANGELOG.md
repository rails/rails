*   Deprecate invalid options passed to `content_for`.
    Before, these options were silently ignored. For example, `content_for :foo, fluhs: true { "bar" }`
    (note the typo) would not flush content.

    *Jeroen Versteeg*

*   Fix tag parameter content being overwritten instead of combined with tag block content.
    Before `tag.div("Hello ") { "World" }` would just return `<div>World</div>`, now it returns `<div>Hello World</div>`.

    *DHH*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
