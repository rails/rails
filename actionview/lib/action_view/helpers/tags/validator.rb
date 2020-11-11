# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class NullValidator
        def validate!(attributes)
          attributes
        end
      end

      class Validator # :nodoc:
        def initialize(object, method_name)
          @object = object
          @method_name = method_name
        end

        def validate!(attributes)
          if validatable?
            attributes["aria-invalid"] ||= invalid? ? "true" : nil
          end

          attributes
        end

        private
          def invalid?
            @object.errors.include?(@method_name)
          end

          def validatable?
            @object.respond_to?(:errors) && @object.errors.respond_to?(:include?)
          end
      end
    end
  end
end
