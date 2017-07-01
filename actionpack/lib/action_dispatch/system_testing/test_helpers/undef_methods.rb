module ActionDispatch
  module SystemTesting
    module TestHelpers
      module UndefMethods # :nodoc:
        extend ActiveSupport::Concern
        included do
          METHODS = %i(get post put patch delete).freeze

          METHODS.each do |verb|
            undef_method verb
          end

          def method_missing(method, *args, &block)
            if METHODS.include?(method)
              raise NoMethodError
            else
              super
            end
          end
        end
      end
    end
  end
end
