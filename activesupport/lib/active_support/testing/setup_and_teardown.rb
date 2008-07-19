module ActiveSupport
  module Testing
    module SetupAndTeardown
      # For compatibility with Ruby < 1.8.6
      PASSTHROUGH_EXCEPTIONS =
        if defined?(Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS)
          Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS
        else
          [NoMemoryError, SignalException, Interrupt, SystemExit]
        end

      def self.included(base)
        base.class_eval do
          include ActiveSupport::Callbacks
          define_callbacks :setup, :teardown

          if defined?(::Mini)
            undef_method :run
            alias_method :run, :run_with_callbacks_and_miniunit
          else
            begin
              require 'mocha'
              undef_method :run
              alias_method :run, :run_with_callbacks_and_mocha
            rescue LoadError
              undef_method :run
              alias_method :run, :run_with_callbacks_and_testunit
            end
          end
        end
      end

      def run_with_callbacks_and_miniunit(runner)
        result = '.'
        begin
          run_callbacks :setup
          result = super
        rescue Exception => e
          result = runner.puke(self.class, self.name, e)
        ensure
          begin
            teardown
            run_callbacks :teardown, :enumerator => :reverse_each
          rescue Exception => e
            result = runner.puke(self.class, self.name, e)
          end
        end
        result
      end

      # This redefinition is unfortunate but test/unit shows us no alternative.
      def run_with_callbacks_and_testunit(result) #:nodoc:
        return if @method_name.to_s == "default_test"

        yield(Test::Unit::TestCase::STARTED, name)
        @_result = result
        begin
          run_callbacks :setup
          setup
          __send__(@method_name)
        rescue Test::Unit::AssertionFailedError => e
          add_failure(e.message, e.backtrace)
        rescue *PASSTHROUGH_EXCEPTIONS
          raise
        rescue Exception
          add_error($!)
        ensure
          begin
            teardown
            run_callbacks :teardown, :enumerator => :reverse_each
          rescue Test::Unit::AssertionFailedError => e
            add_failure(e.message, e.backtrace)
          rescue *PASSTHROUGH_EXCEPTIONS
            raise
          rescue Exception
            add_error($!)
          end
        end
        result.add_run
        yield(Test::Unit::TestCase::FINISHED, name)
      end

      # Doubly unfortunate: mocha does the same so we have to hax their hax.
      def run_with_callbacks_and_mocha(result)
        return if @method_name.to_s == "default_test"

        yield(Test::Unit::TestCase::STARTED, name)
        @_result = result
        begin
          mocha_setup
          begin
            run_callbacks :setup
            setup
            __send__(@method_name)
            mocha_verify { add_assertion }
          rescue Mocha::ExpectationError => e
            add_failure(e.message, e.backtrace)
          rescue Test::Unit::AssertionFailedError => e
            add_failure(e.message, e.backtrace)
          rescue StandardError, ScriptError
            add_error($!)
          ensure
            begin
              teardown
              run_callbacks :teardown, :enumerator => :reverse_each
            rescue Test::Unit::AssertionFailedError => e
              add_failure(e.message, e.backtrace)
            rescue StandardError, ScriptError
              add_error($!)
            end
          end
        ensure
          mocha_teardown
        end
        result.add_run
        yield(Test::Unit::TestCase::FINISHED, name)
      end
    end
  end
end
