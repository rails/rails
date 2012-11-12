require 'active_support/concern'
require 'active_support/callbacks'

module ActiveSupport
  module Testing
    module SetupAndTeardown
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :setup, :teardown

        if defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions
          include ForMiniTest
        else
          include ForClassicTestUnit
        end
      end

      module ClassMethods
        def setup(*args, &block)
          set_callback(:setup, :before, *args, &block)
        end

        def teardown(*args, &block)
          set_callback(:teardown, :after, *args, &block)
        end
      end

      module ForMiniTest
        def run(runner)
          result = '.'
          begin
            _run_setup_callbacks do
              result = super
            end
          rescue Exception => e
            result = runner.puke(self.class, method_name, e)
          ensure
            begin
              _run_teardown_callbacks
            rescue Exception => e
              result = runner.puke(self.class, method_name, e)
            end
          end
          result
        end
      end

      module ForClassicTestUnit
        # For compatibility with Ruby < 1.8.6
        PASSTHROUGH_EXCEPTIONS = Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS rescue [NoMemoryError, SignalException, Interrupt, SystemExit]

        # This redefinition is unfortunate but test/unit shows us no alternative.
        # Doubly unfortunate: hax to support Mocha's hax.
        def run(result)
          return if @method_name.to_s == "default_test"

          mocha_counter = retrieve_mocha_counter(self, result)
          yield(Test::Unit::TestCase::STARTED, name)
          @_result = result

          begin
            begin
              _run_setup_callbacks do
                setup
                __send__(@method_name)
                mocha_verify(mocha_counter) if mocha_counter
              end
            rescue Mocha::ExpectationError => e
              add_failure(e.message, e.backtrace)
            rescue Test::Unit::AssertionFailedError => e
              add_failure(e.message, e.backtrace)
            rescue Exception => e
              raise if PASSTHROUGH_EXCEPTIONS.include?(e.class)
              add_error(e)
            ensure
              begin
                teardown
                _run_teardown_callbacks
              rescue Mocha::ExpectationError => e
                add_failure(e.message, e.backtrace)
              rescue Test::Unit::AssertionFailedError => e
                add_failure(e.message, e.backtrace)
              rescue Exception => e
                raise if PASSTHROUGH_EXCEPTIONS.include?(e.class)
                add_error(e)
              end
            end
          ensure
            mocha_teardown if mocha_counter
          end

          result.add_run
          yield(Test::Unit::TestCase::FINISHED, name)
        end

        protected

        def retrieve_mocha_counter(test_case, result) #:nodoc:
          if respond_to?(:mocha_verify) # using mocha
            if defined?(Mocha::TestCaseAdapter::AssertionCounter)
              Mocha::TestCaseAdapter::AssertionCounter.new(result)
            elsif defined?(Mocha::Integration::TestUnit::AssertionCounter)
              Mocha::Integration::TestUnit::AssertionCounter.new(result)
            else
              Mocha::Integration::AssertionCounter.new(test_case)
            end
          end
        end
      end
    end
  end
end
