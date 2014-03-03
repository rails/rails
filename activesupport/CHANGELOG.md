*   Fixing discrepancy between date and time to_s(:long) and I18n.localize(date, format: long).
    Previously, a call to date.to_s(:long) when there was only one digit in the day would cause
    a zero to be added, while calling I18n.localize(date, format: long) would add an unnecessary
    space. Now, both calls return the date/time without the zero and the space.

    Fixes #14245.

    *Thales Oliveira*

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
