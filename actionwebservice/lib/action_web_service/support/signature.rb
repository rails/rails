module ActionWebService # :nodoc:
  # Action Web Service parameter specifiers may contain symbols or strings
  # instead of Class objects, for a limited set of base types.
  #
  # This provides an unambiguous way to specify that a given parameter
  # contains an integer or boolean value, for example.
  #
  # The allowed set of symbol/string aliases:
  #
  # [<tt>:int</tt>]     any integer value
  # [<tt>:float</tt>]   any floating point value
  # [<tt>:string</tt>]  any string value
  # [<tt>:bool</tt>]    any boolean value
  # [<tt>:time</tt>]    any value containing both date and time
  # [<tt>:date</tt>]    any value containing only a date
  module Signature
    class SignatureError < StandardError # :nodoc:
    end

    private
      def canonical_signature(params)
        return nil if params.nil?
        params.map do |param|
          klass = signature_parameter_class(param)
          if param.is_a?(Hash)
            param[param.keys[0]] = klass
            param
          else
            klass
          end
        end
      end
  
      def signature_parameter_class(param)
        param = param.is_a?(Hash) ? param.values[0] : param
        is_array = param.is_a?(Array)
        param = is_array ? param[0] : param
        param = param.is_a?(String) ? param.to_sym : param
        param = param.is_a?(Symbol) ? signature_ruby_class(param) : param
        is_array ? [param] : param
      end
  
  
      def canonical_signature_base_type(base_type)
        base_type = base_type.to_sym
        case base_type
          when :int, :integer, :fixnum, :bignum
            :int
          when :string, :base64
            :string
          when :bool, :boolean
            :bool
          when :float, :double
            :float
          when :time, :datetime, :timestamp
            :time
          when :date
            :date
          else
            raise(SignatureError, ":#{base_type} is not an ActionWebService base type")
        end
      end
  
      def signature_ruby_class(base_type)
        case canonical_signature_base_type(base_type)
        when :int
          Integer
        when :string
          String
        when :bool
          TrueClass
        when :float
          Float
        when :time
          Time
        when :date
          Date
        end
      end
  
      def signature_base_type(ruby_class)
        case ruby_class
        when Bignum, Integer, Fixnum
          :int
        when String
          :string
        when TrueClass, FalseClass
          :bool
        when Float, Numeric, Precision
          :float
        when Time, DateTime
          :time
        when Date
          :date
        else
          raise(SignatureError, "#{ruby_class.name} is not an ActionWebService base type")
        end
      end
  end
end
