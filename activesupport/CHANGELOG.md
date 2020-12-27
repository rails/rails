*   Add `ActiveSupport::ConstantResolver` module to resolve partial constant names.

    Ruby doesn't resolve partial constant names by default. So in order to make this work, the `ConstantResolver`
    module overrides `#const_missing` and gets prepended in both `Class` and `Module`.

    Without the `ConstantResolver` :

        module Ace
          module Base
            class Case
              class Dice
              end
            end
            class Fase < Case
            end
          end
          class Gas
            include Base
          end

        end

        class Object
          module AddtlGlobalConstants
            class Case
              class Dice
              end
            end
          end
          include AddtlGlobalConstants
        end

        p Ace::Dice
        # => NameError: uninitialized constant Ace::Dice

    With the `ConstantResolver` :

        require "active_support"
        require "active_support/constant_resolver"

        p Ace::Dice
        # => Ace::Base::Case::Dice

    This allows the `#constantize` method to resolve partial names :

        require "active_support/inflector"

        p "Ace::Dice".constantize
        # => Ace::Base::Case::Dice

    Note that the `Inflector` tests still passes when we require the `ConstantResolver` in `test/inflector_test.rb`.

    *Mansa Keïta (mansakondo)*

*   Raises an `ArgumentError` when the first argument of `ActiveSupport::Notification.subscribe` is
    invalid.

    *Vipul A M*

*   `HashWithIndifferentAccess#deep_transform_keys` now returns a `HashWithIndifferentAccess` instead of a `Hash`.

    *Nathaniel Woodthorpe*

*   consume dalli’s `cache_nils` configuration as `ActiveSupport::Cache`'s `skip_nil` when using `MemCacheStore`.

    *Ritikesh G*

*   add `RedisCacheStore#stats` method similar to `MemCacheStore#stats`. Calls `redis#info` internally.

    *Ritikesh G*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activesupport/CHANGELOG.md) for previous changes.
