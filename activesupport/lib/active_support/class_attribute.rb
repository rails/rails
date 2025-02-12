# frozen_string_literal: true

module ActiveSupport
  module ClassAttribute # :nodoc:
    class << self
      def redefine(owner, name, namespaced_name, value)
        if owner.singleton_class?
          if owner.attached_object.is_a?(Module)
            redefine_method(owner, namespaced_name, private: true) { value }
          else
            redefine_method(owner, name) { value }
          end
        end

        redefine_method(owner.singleton_class, namespaced_name, private: true) { value }

        redefine_method(owner.singleton_class, "#{namespaced_name}=", private: true) do |new_value|
          if owner.equal?(self)
            value = new_value
          else
            ::ActiveSupport::ClassAttribute.redefine(self, name, namespaced_name, new_value)
          end
        end
      end

      def redefine_method(owner, name, private: false, &block)
        owner.silence_redefinition_of_method(name)
        owner.define_method(name, &block)
        owner.send(:private, name) if private
      end
    end
  end
end
