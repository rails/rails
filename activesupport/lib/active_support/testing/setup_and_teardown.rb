# frozen_string_literal: true

require "active_support/callbacks"

module ActiveSupport
  module Testing
    # Adds support for +setup+ and +teardown+ callbacks.
    # These callbacks serve as a replacement to overwriting the
    # <tt>#setup</tt> and <tt>#teardown</tt> methods of your TestCase.
    #
    #   class ExampleTest < ActiveSupport::TestCase
    #     setup do
    #       # ...
    #     end
    #
    #     teardown do
    #       # ...
    #     end
    #   end
    module SetupAndTeardown
      def self.prepended(klass)
        klass.include ActiveSupport::Callbacks
        klass.define_callbacks :setup, :test, :teardown
        klass.extend ClassMethods
      end

      module ClassMethods
        # Add a callback, which runs before <tt>TestCase#setup</tt>.
        #
        #   class ClientTest < ActiveSupport::TestCase
        #     setup do
        #       # do client setup
        #     end
        #   end
        def setup(*args, &block)
          set_callback(:setup, :before, *args, &block)
        end

        # Add a callback, which runs after <tt>TestCase#teardown</tt>.
        #
        #   class ClientTest < ActiveSupport::TestCase
        #     teardown do
        #       # do client teardown
        #     end
        #   end
        def teardown(*args, &block)
          set_callback(:teardown, :after, *args, &block)
        end

        # Add a callback, which runs between the <tt>TestCase#setup</tt> callbacks and the <tt>TestCase#teardown</tt> callbacks.
        # Yields the test class instance and the test case to the block:
        #
        #   class ClientTest < ActiveSupport::TestCase
        #     around do |test_case, block|
        #       # do client setup
        #       block.call
        #       # do client teardown
        #     end
        #   end
        #
        # Code after a failing test yielded by the block argument will still be executed.
        def around(*args, &block)
          set_callback(:test, :around, *args, &block)

          include AroundCallbackSupport unless self < AroundCallbackSupport
        end
      end

      module AroundCallbackSupport # :nodoc:
        def send(name, ...) # :nodoc:
          if name.start_with?("test_")
            run_callbacks :test do
              capture_exceptions { super }
            end
          else
            super
          end
        end
      end

      def before_setup # :nodoc:
        super
        run_callbacks :setup
      end

      def after_teardown # :nodoc:
        begin
          run_callbacks :teardown
        rescue => e
          self.failures << Minitest::UnexpectedError.new(e)
        rescue Minitest::Assertion => e
          self.failures << e
        end

        super
      end
    end
  end
end
