*   Fixed `ActiveSupport::Duration#eql?` so that `1.second.eql?(1.second)` is
    true.

    This fixes the current situation of:

        1.second.eql?(1.second) #=> false

    `eql?` also requires that the other object is an `ActiveSupport::Duration`.
    This requirement makes `ActiveSupport::Duration`'s behavior consistent with
    the behavior of Ruby's numeric types:

        1.eql?(1.0) #=> false
        1.0.eql?(1) #=> false

        1.second.eql?(1) #=> false (was true)
        1.eql?(1.second) #=> false

        { 1 => "foo", 1.0 => "bar" }
        #=> { 1 => "foo", 1.0 => "bar" }

        { 1 => "foo", 1.second => "bar" }
        # now => { 1 => "foo", 1.second => "bar" }
        # was => { 1 => "bar" }

    And though the behavior of these hasn't changed, for reference:

        1 == 1.0 #=> true
        1.0 == 1 #=> true

        1 == 1.second #=> true
        1.second == 1 #=> true

    *Emily Dobervich*

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
