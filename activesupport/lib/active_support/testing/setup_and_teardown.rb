module ActiveSupport
  module Testing
    module SetupAndTeardown
      def self.included(base)
        base.extend ClassMethods

        begin
          require 'mocha'
          base.alias_method_chain :run, :callbacks_and_mocha
        rescue LoadError
          base.alias_method_chain :run, :callbacks
        end
      end

      module ClassMethods
        def setup(*method_names, &block)
          method_names << block if block_given?
          (@setup_callbacks ||= []).concat method_names
        end

        def teardown(*method_names, &block)
          method_names << block if block_given?
          (@teardown_callbacks ||= []).concat method_names
        end

        def setup_callback_chain
          @setup_callbacks ||= []

          if superclass.respond_to?(:setup_callback_chain)
            superclass.setup_callback_chain + @setup_callbacks
          else
            @setup_callbacks
          end
        end

        def teardown_callback_chain
          @teardown_callbacks ||= []

          if superclass.respond_to?(:teardown_callback_chain)
            superclass.teardown_callback_chain + @teardown_callbacks
          else
            @teardown_callbacks
          end
        end
      end

      # This redefinition is unfortunate but test/unit shows us no alternative.
      def run_with_callbacks(result) #:nodoc:
        return if @method_name.to_s == "default_test"

        yield(Test::Unit::TestCase::STARTED, name)
        @_result = result
        begin
          run_callbacks :setup
          setup
          __send__(@method_name)
        rescue Test::Unit::AssertionFailedError => e
          add_failure(e.message, e.backtrace)
        rescue *Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS
          raise
        rescue Exception
          add_error($!)
        ensure
          begin
            teardown
            run_callbacks :teardown, :reverse_each
          rescue Test::Unit::AssertionFailedError => e
            add_failure(e.message, e.backtrace)
          rescue *Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS
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
              run_callbacks :teardown, :reverse_each
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

      protected
        def run_callbacks(kind, enumerator = :each)
          self.class.send("#{kind}_callback_chain").send(enumerator) do |callback|
            case callback
            when Proc; callback.call(self)
            when String, Symbol; send!(callback)
            else raise ArgumentError, "Unrecognized callback #{callback.inspect}"
            end
          end
        end
    end
  end
end
