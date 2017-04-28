* Rename ActionDispatch::IntegrationTest into ActionDispatch::IntegrationTestCase

    At the moment we have `ActiveSupport::TestCase`, `ActionCable::TestCase`, `ActionCable::TestCase`,
    `ActionView::TestCase` and finally `ActionDispatch::SystemTestCase`. It feels like `ActionDispatch::IntegrationTest`
    was not respecting the convention of other tests. Now it is.

    *Pierre Schambacher*

*  Add `action_controller_api` and `action_controller_base` load hooks to be called in `ActiveSupport.on_load`

    `ActionController::Base` and `ActionController::API` have differing implementations. This means that
    the one umbrella hook `action_controller` is not able to address certain situations where a method
    may not exist in a certain implementation.

    This is fixed by adding two new hooks so you can target `ActionController::Base` vs `ActionController::API`

    Fixes #27013.

    *Julian Nadeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionpack/CHANGELOG.md) for previous changes.
