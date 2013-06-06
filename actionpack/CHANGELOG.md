*   Set the default `ActionView::Digestor.cache` to `ActiveSupport::Cache::NullStore.new`
    if `ActionView::Base.cache_template_loading` is disabled.

    *Sean Huber*

*   Fix an issue where partials with a number in the filename weren't being digested for cache dependencies.

    *Bryan Ricker*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
