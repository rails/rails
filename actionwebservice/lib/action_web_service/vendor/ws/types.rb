require 'time'
require 'date'

module WS
  module BaseTypes
    class << self
      def type_name_to_class(name)
        case canonical_type_name(name)
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

      def class_to_type_name(klass)
        if WS.derived_from?(Integer, klass) || WS.derived_from?(Fixnum, klass) || WS.derived_from?(Bignum, klass)
          :int
        elsif klass == String
          :string
        elsif klass == TrueClass || klass == FalseClass
          :bool
        elsif WS.derived_from?(Float, klass) || WS.derived_from?(Precision, klass) || WS.derived_from?(Numeric, klass)
          :float
        elsif klass == Time || klass == DateTime
          :time
        elsif klass == Date
          :date
        else
          raise(TypeError, "#{klass} is not a valid base type")
        end
      end

      def base_type?(klass)
        !(canonical_type_class(klass) rescue nil).nil?
      end

      def canonical_type_class(klass)
        type_name_to_class(class_to_type_name(klass))
      end

      def canonical_param_type_class(spec)
        klass = spec.is_a?(Hash) ? spec.values[0] : spec
        array_element_class = klass.is_a?(Array) ? klass[0] : nil
        klass = array_element_class ? array_element_class : klass
        klass = type_name_to_class(klass) if klass.is_a?(Symbol) || klass.is_a?(String)
        base_class = canonical_type_class(klass) rescue nil
        klass = base_class unless base_class.nil?
        array_element_class ? [klass] : klass
      end

      def canonical_param_type_spec(spec)
        klass = canonical_param_type_class(spec)
        spec.is_a?(Hash) ? {spec.keys[0]=>klass} : klass
      end

      def canonical_type_name(name)
        name = name.to_sym
        case name
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
            raise(TypeError, "#{name} is not a valid base type")
        end
      end
    end
  end

  class Param
    attr_accessor :value
    attr_accessor :info

    def initialize(value, info)
      @value = value
      @info = info
    end
  end

  class ParamInfo
    attr_accessor :name
    attr_accessor :type
    attr_accessor :data

    def initialize(name, type, data=nil)
      @name = name
      @type = type
      @data = data
    end

    def self.create(spec, index=nil, data=nil)
      name = spec.is_a?(Hash) ? spec.keys[0].to_s : (index ? "param#{index}" : nil)
      type = BaseTypes.canonical_param_type_class(spec)
      ParamInfo.new(name, type, data)
    end
  end

  class BaseTypeCaster
    def initialize
      @handlers = {}
      install_handlers
    end

    def cast(value, klass)
      type_class = BaseTypes.canonical_type_class(klass)
      return value unless type_class
      @handlers[type_class].call(value, type_class)
    end

    protected
      def install_handlers
        handler = method(:cast_base_type)
        [:int, :string, :bool, :float, :time, :date].each do |name|
          type = BaseTypes.type_name_to_class(name)
          @handlers[type] = handler
        end
        @handlers[Fixnum] = handler
      end

      def cast_base_type(value, type_class)
        desired_class = BaseTypes.canonical_type_class(type_class)
        value_class = BaseTypes.canonical_type_class(value.class)
        return value if desired_class == value_class
        desired_name = BaseTypes.class_to_type_name(desired_class)
        case desired_name
        when :int
          Integer(value)
        when :string
          value.to_s
        when :bool
          return false if value.nil?
          value = value.to_s
          return true if value == 'true'
          return false if value == 'false'
          raise(TypeError, "can't convert #{value} to boolean")
        when :float
          Float(value)
        when :time
          Time.parse(value.to_s)
        when :date
          Date.parse(value.to_s)
        end
      end
  end
end
