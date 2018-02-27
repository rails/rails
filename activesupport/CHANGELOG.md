## Rails 6.0.0.alpha (Unreleased) ##

*   Add `private: true` option to ActiveSupport's `delegate`.

    In order to delegate methods as private methods:

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

    More information in #31944.

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

*   Adds parallel testing to Rails

    Parallelize your test suite with forked processes or threads.

    *Eileen M. Uchitelle*, *Aaron Patterson*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activesupport/CHANGELOG.md) for previous changes.
