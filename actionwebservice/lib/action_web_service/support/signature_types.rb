module ActionWebService # :nodoc:
  module SignatureTypes # :nodoc:
    def canonical_signature(signature)
      return nil if signature.nil?
      i = -1
      signature.map{ |spec| canonical_signature_entry(spec, i += 1) }
    end

    def canonical_signature_entry(spec, i)
      name = "param#{i}"
      if spec.is_a?(Hash)
        name = spec.keys.first
        spec = spec.values.first
        type = spec
      else
        type = spec
      end
      if spec.is_a?(Array)
        ArrayType.new(canonical_signature_entry(spec[0], 0), name)
      else
        type = canonical_type(type)
        if type.is_a?(Symbol)
          BaseType.new(type, name)
        else
          StructuredType.new(type, name)
        end
      end
    end

    def canonical_type(type)
      type_name = symbol_name(type) || class_to_type_name(type)
      type = type_name || type
      return canonical_type_name(type) if type.is_a?(Symbol)
      type
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
        when :time, :timestamp
          :time
        when :datetime
          :datetime
        when :date
          :date
        else
          raise(TypeError, "#{name} is not a valid base type")
      end
    end

    def canonical_type_class(type)
      type = canonical_type(type)
      type.is_a?(Symbol) ? type_name_to_class(type) : type
    end

    def symbol_name(name)
      return name.to_sym if name.is_a?(Symbol) || name.is_a?(String)
      nil
    end

    def class_to_type_name(klass)
      klass = klass.class unless klass.is_a?(Class)
      if derived_from?(Integer, klass) || derived_from?(Fixnum, klass) || derived_from?(Bignum, klass)
        :int
      elsif klass == String
        :string
      elsif klass == TrueClass || klass == FalseClass
        :bool
      elsif derived_from?(Float, klass) || derived_from?(Precision, klass) || derived_from?(Numeric, klass)
        :float
      elsif klass == Time
        :time
      elsif klass == DateTime
        :datetime
      elsif klass == Date
        :date
      else
        nil
      end
    end

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
      when :datetime
        DateTime
      else
        nil
      end
    end

    def derived_from?(ancestor, child)
      child.ancestors.include?(ancestor)
    end

    module_function :type_name_to_class
    module_function :class_to_type_name
    module_function :symbol_name
    module_function :canonical_type_class
    module_function :canonical_type_name
    module_function :canonical_type
    module_function :canonical_signature_entry
    module_function :canonical_signature
    module_function :derived_from?
  end

  class BaseType # :nodoc:
    include SignatureTypes

    attr :type
    attr :type_class
    attr :name

    def initialize(type, name)
      @type = canonical_type(type)
      @type_class = canonical_type_class(@type)
      @name = name
    end

    def custom?
      false
    end

    def array?
      false
    end

    def structured?
      false
    end
  end

  class ArrayType < BaseType # :nodoc:
    attr :element_type

    def initialize(element_type, name)
      super(Array, name)
      @element_type = element_type
    end

    def custom?
      true
    end

    def array?
      true
    end
  end

  class StructuredType < BaseType # :nodoc:
    def each_member
      if @type_class.respond_to?(:members)
        @type_class.members.each do |name, type|
          yield name, type
        end
      elsif @type_class.respond_to?(:columns)
        i = 0
        @type_class.columns.each do |column|
          yield column.name, canonical_signature_entry(column.klass, i += 1)
        end
      end
    end

    def custom?
      true
    end

    def structured?
      true
    end
  end
end
