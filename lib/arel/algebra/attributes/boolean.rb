module Arel
  module Attributes
    class Boolean < Attribute
      def type_cast(value)
        case value
        when true, false then value
        # when nil            then options[:allow_nil] ? nil : false
        when nil         then false
        when 1           then true
        when 0           then false
        else
          case value.to_s.downcase.strip
          when 'true'  then true
          when 'false' then false
          else         raise typecast_error(value)
          end
        end
      end
    end
  end
end
