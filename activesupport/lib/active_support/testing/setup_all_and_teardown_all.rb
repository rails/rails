require "active_support/concern"
require "active_support/callbacks"

module ActiveSupport
  module Testing
    # Add support for +setup_all+ and +teardown_all+ callbacks.
    module SetupAllAndTeardownAll
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :setup_all, :teardown_all
      end

      module ClassMethods
        def run(reporter, options = {})
          @reporter = reporter
          @instance = run_callbacks :setup_all
          super(reporter, options)
          run_callbacks :teardown_all
        end

        # Return a singleton instance for running individual tests,
        # so instance variables can be duplicated across all tests and callbacks.
        def new(name)
          @instance ||= super
          instance = @instance.dup
          instance.name = name
          instance.failures = []
          instance
        end

        private

          def run_callbacks(name)
            instance = new("run_callbacks")
            instance.time_it do
              instance.capture_exceptions do
                instance.run_callbacks(name)
              end
            end
            @reporter.record instance if instance.failure
            instance
          end

          def setup_all(*args, &block)
            set_callback(:setup_all, :before, *args, &block)
          end

          def teardown_all(*args, &block)
            set_callback(:teardown_all, :after, *args, &block)
          end
      end
    end
  end
end
