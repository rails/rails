# frozen_string_literal: true

module ActiveSupport
  module ClassAttribute # :nodoc:
    class << self
      def redefine(owner, name, value)
        if owner.singleton_class?
          owner.redefine_method(name) { value }
          owner.send(:public, name)
        end

        owner.redefine_singleton_method(name) { value }
        owner.singleton_class.send(:public, name)

        owner.redefine_singleton_method("#{name}=") do |new_value|
          if owner.equal?(self)
            value = new_value
          else
            ::ActiveSupport::ClassAttribute.redefine(self, name, new_value)
          end
        end
        owner.singleton_class.send(:public, "#{name}=")
      end
    end
  end
end
