module ActiveSupport
  module Testing
    module SetupAndTeardown
      def self.included(base)
        base.class_eval do
          extend ClassMethods

          include ActiveSupport::Callbacks
          define_callbacks :test

          if defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions
            include ForMiniTest
          else
            include ForClassicTestUnit
          end
        end
      end

      module ClassMethods
        def setup(*args, &block)
          set_callback(:test, :before, *args, &block)
        end

        def teardown(*args, &block)
          set_callback(:test, :after, *args, &block)
        end

        def wrap(*args, &block)
          set_callback(:test, :around, *args, &block)
        end
      end

      module ForMiniTest
        def run(runner)
          result = '.'
          begin
            run_callbacks :test do
              begin
                result = super
              rescue Exception => e
                result = runner.puke(self.class, self.name, e)
              end
            end
          rescue Exception => e
            result = runner.puke(self.class, self.name, e)
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

          if using_mocha = respond_to?(:mocha_verify)
            assertion_counter_klass = if defined?(Mocha::TestCaseAdapter::AssertionCounter)
                                        Mocha::TestCaseAdapter::AssertionCounter
                                      else
                                        Mocha::Integration::TestUnit::AssertionCounter
                                      end
            assertion_counter = assertion_counter_klass.new(result)
          end

          yield(Test::Unit::TestCase::STARTED, name)
          @_result = result
          begin
            begin
              run_callbacks :test do
                begin
                  setup
                  __send__(@method_name)
                  mocha_verify(assertion_counter) if using_mocha
                rescue Mocha::ExpectationError => e
                  add_failure(e.message, e.backtrace)
                rescue Test::Unit::AssertionFailedError => e
                  add_failure(e.message, e.backtrace)
                rescue Exception => e
                  raise if PASSTHROUGH_EXCEPTIONS.include?(e.class)
                  add_error(e)
                ensure
                  teardown
                end
              end
            rescue Test::Unit::AssertionFailedError => e
              add_failure(e.message, e.backtrace)
            rescue Exception => e
              raise if PASSTHROUGH_EXCEPTIONS.include?(e.class)
              add_error(e)
            end
          ensure
            mocha_teardown if using_mocha
          end
          result.add_run
          yield(Test::Unit::TestCase::FINISHED, name)
        end
      end
    end
  end
end
