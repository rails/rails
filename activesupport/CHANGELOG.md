*   Fix bug where `ActiveSupport::Timezone.all` would fail when tzinfo data for
    any timezone defined in `ActiveSupport::MAPPING` is missing.

    *Dominik Sander*

*   Redis cache store: `delete_matched` no longer blocks the Redis server.
    (Switches from evaled Lua to a batched SCAN + DEL loop.)

    *Gleb Mazovetskiy*

*   Fix bug where `ActiveSupport::Cache` will massively inflate the storage
    size when compression is enabled (which is true by default). This patch
    does not attempt to repair existing data: please manually flush the cache
    to clear out the problematic entries.

    *Godfrey Chan*

*   Fix bug where `URI.unscape` would fail with mixed Unicode/escaped character input:

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
