require 'active_support/concern'
require 'active_support/callbacks'

module ActiveSupport
  module Testing
    module SetupAndTeardown

      PASSTHROUGH_EXCEPTIONS = [
        NoMemoryError,
        SignalException,
        Interrupt,
        SystemExit
      ]

      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :setup, :teardown

      end

      module ClassMethods
        def setup(*args, &block)
          set_callback(:setup, :before, *args, &block)
        end

        def teardown(*args, &block)
          set_callback(:teardown, :after, *args, &block)
        end
      end

      def run(runner)
        result = '.'
        begin
          run_callbacks :setup do
            result = super
          end
        rescue *PASSTHROUGH_EXCEPTIONS
          raise
        rescue Exception => e
          result = runner.puke(self.class, method_name, e)
        ensure
          begin
            run_callbacks :teardown
          rescue *PASSTHROUGH_EXCEPTIONS
            raise
          rescue Exception => e
            result = runner.puke(self.class, method_name, e)
          end
        end
        result
      end

    end
  end
end
