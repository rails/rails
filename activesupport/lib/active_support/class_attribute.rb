# frozen_string_literal: true

module ActiveSupport
  module ClassAttribute # :nodoc:
    class << self
      def redefine(owner, name, value)
        if owner.singleton_class?
          owner.redefine_method(name) { value }
          owner.silence_redefinition_of_method(name)
        end

        owner.redefine_singleton_method(name) { value }
        owner.redefine_singleton_method("#{name}=") do |new_value|
          if owner.equal?(self)
            value = new_value
          else
            ::ActiveSupport::ClassAttribute.redefine(self, name, new_value)
          end
        end
      end
    end
  end
end
