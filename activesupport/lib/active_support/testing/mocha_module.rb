module ActiveSupport
  module Testing
    module MochaModule
      begin
        require 'mocha/api'
        require 'mocha/expectation_error_factory'
        require 'minitest/unit'

        include Mocha::API

        def self.included(mod)
          Mocha::ExpectationErrorFactory.exception_class = ::MiniTest::Assertion
        end

        def before_setup
          mocha_setup
          super
        end

        def before_teardown
          return unless passed?
          mocha_verify
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
