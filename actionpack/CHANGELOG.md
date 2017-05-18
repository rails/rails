*   Change the cache key format for fragments to make it easier to debug key churn. The new format is:

        views/template/action.html.erb:7a1156131a6928cb0026877f8b749ac9/projects/123
              ^template path           ^template tree digest            ^class   ^id

    *DHH*

*   Add support for recyclable cache keys with fragment caching. This uses the new versioned entries in the
    `ActiveSupport::Cache` stores and relies on the fact that Active Record has split `#cache_key` and `#cache_version`
    to support it.

    *DHH*

*   Add `action_controller_api` and `action_controller_base` load hooks to be called in `ActiveSupport.on_load`

    `ActionController::Base` and `ActionController::API` have differing implementations. This means that
    the one umbrella hook `action_controller` is not able to address certain situations where a method
    may not exist in a certain implementation.

    This is fixed by adding two new hooks so you can target `ActionController::Base` vs `ActionController::API`

    Fixes #27013.

    *Julian Nadeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionpack/CHANGELOG.md) for previous changes.
