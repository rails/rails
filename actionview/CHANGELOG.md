*   Add template precompilation support.

    View templates can now be eagerly compiled at boot time when
    `config.action_view.precompile_templates = true` (enabled by default in
    `load_defaults "8.2"`) and `config.eager_load` is also `true`. This
    improves cold render times and allows more memory to be shared via
    copy-on-write on forking web servers.

    The precompiler scans view templates, controllers, and helpers for
    `render` calls, detects implicit controller action renders, and supports
    engine view paths. Invalid templates raise errors at boot time rather
    than failing silently.

    Additional directories can be scanned for `render` calls using
    `config.action_view.precompile_additional_paths`.

    Emits a `precompile_templates.action_view` notification with `:count`
    in the payload.

    Based on the `actionview_precompiler` gem by John Hawthorn. GitHub has
    used this optimization for over 5 years, saving an estimated ~500MB of
    memory per container (each with 11 forked workers) for ~7,000 templates.

    *Joel Hawksley*, *John Hawthorn*

*   Skip blank attribute names in tag helpers to avoid generating invalid HTML.

    *Mike Dalessio*

*   Fix tag parameter content being overwritten instead of combined with tag block content.
    Before `tag.div("Hello ") { "World" }` would just return `<div>World</div>`, now it returns `<div>Hello World</div>`.

    *DHH*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
