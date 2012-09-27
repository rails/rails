require 'active_support/concern'
require 'active_support/callbacks'

module ActiveSupport
  module Testing
    module SetupAndTeardown
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

      def before_setup
        super
        run_callbacks :setup
      end

      def after_teardown
        run_callbacks :teardown
        super
      end
    end
  end
end
