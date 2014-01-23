module ActiveModel
  module Validations
    class WithValidator < EachValidator # :nodoc:
      def validate_each(record, attr, val)
        method_name = options[:with]

        if record.method(method_name).arity == 0
          record.send method_name
        else
          record.send method_name, attr
        end
      end
    end
  end
end
