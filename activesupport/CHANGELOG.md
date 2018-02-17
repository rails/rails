## Rails 6.0.0.alpha (Unreleased) ##

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
