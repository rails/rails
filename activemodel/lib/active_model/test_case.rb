require "active_support/test_case"

module ActiveModel #:nodoc:
  class TestCase < ActiveSupport::TestCase #:nodoc:
    def with_kcode(kcode)
      if RUBY_VERSION < '1.9'
        orig_kcode, $KCODE = $KCODE, kcode
        begin
          yield
        ensure
          $KCODE = orig_kcode
        end
      else
        yield
      end
    end
  end
end
