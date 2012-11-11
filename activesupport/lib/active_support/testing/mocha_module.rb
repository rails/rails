module ActiveSupport
  module Testing
    module MochaModule
      begin
        require 'mocha/api'
        begin
          silence_warnings { require 'mocha/expectation_error_factory' }
        rescue LoadError => e
        end
        require 'minitest/unit'

        include Mocha::API

        def self.included(mod)
          if defined?(Mocha::ExpectationErrorFactory)
            Mocha::ExpectationErrorFactory.exception_class = ::MiniTest::Assertion
          end
        end

        class AssertionCounter
          def initialize(test_case)
            @test_case = test_case
          end

          def increment
            @test_case.assert(true)
          end
        end

        def before_setup
          mocha_setup
          super
        end

        def before_teardown
          return unless passed?
          assertion_counter = AssertionCounter.new(self)
          mocha_verify(assertion_counter)
        ensure
          super
        end

        def after_teardown
          super
          mocha_teardown
        end
      rescue LoadError
      end
    end
  end
end
