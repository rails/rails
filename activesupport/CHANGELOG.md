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
