*   `ActiveSupport::SafeBuffer#prepend` acts like `String#prepend` and modifies
    instance in-place, returning self. `ActiveSupport::SafeBuffer#prepend!` is
    deprecated.

    *Pavel Pravosud*

*   `HashWithIndifferentAccess` better respects `#to_hash` on objects it's
    given. In particular, `.new`, `#update`, `#merge`, `#replace` all accept
    objects which respond to `#to_hash`, even if those objects are not Hashes
    directly.

    *Peter Jaros*

*   Deprecate `Class#superclass_delegating_accessor`, use `Class#class_attribute` instead.

    *Akshay Vishnoi*

*   Ensure classes which `include Enumerable` get `#to_json` in addition to
    `#as_json`.

    *Sammy Larbi*

*   Change the signature of `fetch_multi` to return a hash rather than an
    array. This makes it consistent with the output of `read_multi`.

    *Parker Selbert*

*   Introduce `Concern#class_methods` as a sleek alternative to clunky
    `module ClassMethods`. Add `Kernel#concern` to define at the toplevel
    without chunky `module Foo; extend ActiveSupport::Concern` boilerplate.

        # app/models/concerns/authentication.rb
        concern :Authentication do
          included do
            after_create :generate_private_key
          end

          class_methods do
            def authenticate(credentials)
              # ...
            end
          end

          def generate_private_key
            # ...
          end
        end

        # app/models/user.rb
        class User < ActiveRecord::Base
          include Authentication
        end

    *Jeremy Kemper*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activesupport/CHANGELOG.md) for previous changes.
