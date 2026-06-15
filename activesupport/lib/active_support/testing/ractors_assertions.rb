# frozen_string_literal: true

module ActiveSupport
  module Testing
    module RactorsAssertions # :nodoc: all
      private
        if RUBY_VERSION >= "4.0"
          def assert_ractor_make_shareable(obj)
            assert_nothing_raised { Ractor.make_shareable(obj) }
          end

          def assert_ractor_shareable(obj)
            assert Ractor.shareable?(obj), "Expected #{obj.inspect} to be shareable, but it is not."
          end
        else
          def assert_ractor_make_shareable(obj)
            assert true
          end

          def assert_ractor_shareable(obj)
            assert true
          end
        end
    end
  end
end
