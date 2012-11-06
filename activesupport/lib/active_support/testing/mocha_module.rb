module ActiveSupport
  module Testing
    module MochaModule
      begin
        require 'mocha/api'
        include Mocha::API

        def before_setup
          mocha_setup
          super
        end

        def after_teardown
          super
          mocha_verify
          mocha_teardown
        end
      rescue LoadError
      end
    end
  end
end
