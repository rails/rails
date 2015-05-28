require 'active_record/attribute'

module ActiveRecord
  class Attribute # :nodoc:
    class UserProvidedDefault < FromUser
      def initialize(name, value, type)
        super(name, value, type)
      end

      def type_cast(value)
        if value.is_a?(Proc)
          super(value.call)
        else
          super
        end
      end
    end
  end
end
