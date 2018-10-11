*   Add `ActiveSupport::ParameterFilter`.

    *Yoshiyuki Kinjo*

*   Rename `Module#parent`, `Module#parents`, and `Module#parent_name` to
    `module_parent`, `module_parents`, and `module_parent_name`.

    *Gannon McGibbon*

*   Deprecate the use of `LoggerSilence` in favor of `ActiveSupport::LoggerSilence`

    *Edouard Chin*

*   Deprecate using negative limits in `String#first` and `String#last`.

    *Gannon McGibbon*, *Eric Turner*

*   Fix bug where `#without` for `ActiveSupport::HashWithIndifferentAccess` would fail
    with symbol arguments

    *Abraham Chan*

*   Treat `#delete_prefix`, `#delete_suffix` and `#unicode_normalize` results as non-`html_safe`.
    Ensure safety of arguments for `#insert`, `#[]=` and `#replace` calls on `html_safe` Strings.

    *Janosch Müller*

*   Changed `ActiveSupport::TaggedLogging.new` to return a new logger instance instead
    of mutating the one received as parameter.

    *Thierry Joyal*

*   Define `unfreeze_time` as an alias of `travel_back` in `ActiveSupport::Testing::TimeHelpers`.

    The alias is provided for symmetry with `freeze_time`.

    *Ryan Davidson*

*   Add support for tracing constant autoloads. Just throw

        ActiveSupport::Dependencies.logger = Rails.logger
        ActiveSupport::Dependencies.verbose = true

    in an initializer.

    *Xavier Noria*

*   Maintain `html_safe?` on html_safe strings when sliced.

        string = "<div>test</div>".html_safe
        string[-1..1].html_safe? # => true

    *Elom Gomez*, *Yumin Wong*

*   Add `Array#extract!`.

    The method removes and returns the elements for which the block returns a true value.
    If no block is given, an Enumerator is returned instead.

        numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        odd_numbers = numbers.extract! { |number| number.odd? } # => [1, 3, 5, 7, 9]
        numbers # => [0, 2, 4, 6, 8]

    *bogdanvlviv*

*   Support not to cache `nil` for `ActiveSupport::Cache#fetch`.

        cache.fetch('bar', skip_nil: true) { nil }
        cache.exist?('bar') # => false

    *Martin Hong*

*   Add "event object" support to the notification system.
    Before this change, end users were forced to create hand made artisanal
    event objects on their own, like this:

        ActiveSupport::Notifications.subscribe('wait') do |*args|
          @event = ActiveSupport::Notifications::Event.new(*args)
        end

        ActiveSupport::Notifications.instrument('wait') do
          sleep 1
        end

        @event.duration # => 1000.138

    After this change, if the block passed to `subscribe` only takes one
    parameter, the framework will yield an event object to the block.  Now
    end users are no longer required to make their own:

        ActiveSupport::Notifications.subscribe('wait') do |event|
          @event = event
        end

        ActiveSupport::Notifications.instrument('wait') do
          sleep 1
        end

        p @event.allocations # => 7
        p @event.cpu_time    # => 0.256
        p @event.idle_time   # => 1003.2399

    Now you can enjoy event objects without making them yourself.  Neat!

    *Aaron "t.lo" Patterson*

*   Add cpu_time, idle_time, and allocations to Event.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   RedisCacheStore: support key expiry in increment/decrement.

    Pass `:expires_in` to `#increment` and `#decrement` to set a Redis EXPIRE on the key.

    If the key is already set to expire, RedisCacheStore won't extend its expiry.

        Rails.cache.increment("some_key", 1, expires_in: 2.minutes)

    *Jason Lee*

*   Allow `Range#===` and `Range#cover?` on Range.

    `Range#cover?` can now accept a range argument like `Range#include?` and
    `Range#===`. `Range#===` works correctly on Ruby 2.6. `Range#include?` is moved
    into a new file, with these two methods.

    *Requiring active_support/core_ext/range/include_range is now deprecated.*
    *Use `require "active_support/core_ext/range/compare_range"` instead.*

    *utilum*

*   Add `index_with` to Enumerable.

    Allows creating a hash from an enumerable with the value from a passed block
    or a default argument.

        %i( title body ).index_with { |attr| post.public_send(attr) }
        # => { title: "hey", body: "what's up?" }

        %i( title body ).index_with(nil)
        # => { title: nil, body: nil }

    Closely linked with `index_by`, which creates a hash where the keys are extracted from a block.

    *Kasper Timm Hansen*

*   Fix bug where `ActiveSupport::Timezone.all` would fail when tzinfo data for
    any timezone defined in `ActiveSupport::TimeZone::MAPPING` is missing.

    *Dominik Sander*

*   Redis cache store: `delete_matched` no longer blocks the Redis server.
    (Switches from evaled Lua to a batched SCAN + DEL loop.)

    *Gleb Mazovetskiy*

*   Fix bug where `ActiveSupport::Cache` will massively inflate the storage
    size when compression is enabled (which is true by default). This patch
    does not attempt to repair existing data: please manually flush the cache
    to clear out the problematic entries.

    *Godfrey Chan*

*   Fix bug where `URI.unescape` would fail with mixed Unicode/escaped character input:

        URI.unescape("\xe3\x83\x90")  # => "バ"
        URI.unescape("%E3%83%90")  # => "バ"
        URI.unescape("\xe3\x83\x90%E3%83%90")  # => Encoding::CompatibilityError

    *Ashe Connor*, *Aaron Patterson*

*   Add `before?` and `after?` methods to `Date`, `DateTime`,
    `Time`, and `TimeWithZone`.

    *Nick Holden*

*   `ActiveSupport::Inflector#ordinal` and `ActiveSupport::Inflector#ordinalize` now support
    translations through I18n.

        # locale/fr.rb

        {
          fr: {
            number: {
              nth: {
                ordinals: lambda do |_key, number:, **_options|
                  if number.to_i.abs == 1
                    'er'
                  else
                    'e'
                  end
                end,

                ordinalized: lambda do |_key, number:, **_options|
                  "#{number}#{ActiveSupport::Inflector.ordinal(number)}"
                end
              }
            }
          }
        }


    *Christian Blais*

*   Add `:private` option to ActiveSupport's `Module#delegate`
    in order to delegate methods as private:

        class User < ActiveRecord::Base
          has_one :profile
          delegate :date_of_birth, to: :profile, private: true

          def age
            Date.today.year - date_of_birth.year
          end
        end

        # User.new.age  # => 29
        # User.new.date_of_birth
        # => NoMethodError: private method `date_of_birth' called for #<User:0x00000008221340>

    *Tomas Valent*

*   `String#truncate_bytes` to truncate a string to a maximum bytesize without
    breaking multibyte characters or grapheme clusters like 👩‍👩‍👦‍👦.

    *Jeremy Daer*

*   `String#strip_heredoc` preserves frozenness.

        "foo".freeze.strip_heredoc.frozen?  # => true

    Fixes that frozen string literals would inadvertently become unfrozen:

        # frozen_string_literal: true

        foo = <<-MSG.strip_heredoc
          la la la
        MSG

        foo.frozen?  # => false !??

    *Jeremy Daer*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*

*   Adds parallel testing to Rails.

    Parallelize your test suite with forked processes or threads.

    *Eileen M. Uchitelle*, *Aaron Patterson*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activesupport/CHANGELOG.md) for previous changes.
