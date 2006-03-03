module ActionWebService # :nodoc:
  # Action Web Service supports the following base types in a signature:
  #
  # [<tt>:int</tt>]      Represents an integer value, will be cast to an integer using <tt>Integer(value)</tt>
  # [<tt>:string</tt>]   Represents a string value, will be cast to an string using the <tt>to_s</tt> method on an object
  # [<tt>:base64</tt>]   Represents a Base 64 value, will contain the binary bytes of a Base 64 value sent by the caller
  # [<tt>:bool</tt>]     Represents a boolean value, whatever is passed will be cast to boolean (<tt>true</tt>, '1', 'true', 'y', 'yes' are taken to represent true; <tt>false</tt>, '0', 'false', 'n', 'no' and <tt>nil</tt> represent false)
  # [<tt>:float</tt>]    Represents a floating point value, will be cast to a float using <tt>Float(value)</tt>
  # [<tt>:time</tt>]     Represents a timestamp, will be cast to a <tt>Time</tt> object
  # [<tt>:datetime</tt>] Represents a timestamp, will be cast to a <tt>DateTime</tt> object
  # [<tt>:date</tt>]     Represents a date, will be cast to a <tt>Date</tt> object
  #
  # For structured types, you'll need to pass in the Class objects of
  # ActionWebService::Struct and ActiveRecord::Base derivatives.
  module SignatureTypes
    def canonical_signature(signature) # :nodoc:
      return nil if signature.nil?
      unless signature.is_a?(Array)
        raise(ActionWebServiceError, "Expected signature to be an Array")
      end
      i = -1
      signature.map{ |spec| canonical_signature_entry(spec, i += 1) }
    end

    def canonical_signature_entry(spec, i) # :nodoc:
      orig_spec = spec
      name = "param#{i}"
      if spec.is_a?(Hash)
        name, spec = spec.keys.first, spec.values.first
      end
      type = spec
      if spec.is_a?(Array)
        ArrayType.new(orig_spec, canonical_signature_entry(spec[0], 0), name)
      else
        type = canonical_type(type)
        if type.is_a?(Symbol)
          BaseType.new(orig_spec, type, name)
        else
          StructuredType.new(orig_spec, type, name)
        end
      end
    end

    def canonical_type(type) # :nodoc:
      type_name = symbol_name(type) || class_to_type_name(type)
      type = type_name || type
      return canonical_type_name(type) if type.is_a?(Symbol)
      type
    end

    def canonical_type_name(name) # :nodoc:
      name = name.to_sym
      case name
        when :int, :integer, :fixnum, :bignum
          :int
        when :string, :text
          :string
        when :base64, :binary
          :base64
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

    def canonical_type_class(type) # :nodoc:
      type = canonical_type(type)
      type.is_a?(Symbol) ? type_name_to_class(type) : type
    end

    def symbol_name(name) # :nodoc:
      return name.to_sym if name.is_a?(Symbol) || name.is_a?(String)
      nil
    end

    def class_to_type_name(klass) # :nodoc:
      klass = klass.class unless klass.is_a?(Class)
      if derived_from?(Integer, klass) || derived_from?(Fixnum, klass) || derived_from?(Bignum, klass)
        :int
      elsif klass == String
        :string
      elsif klass == Base64
        :base64
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

    def type_name_to_class(name) # :nodoc:
      case canonical_type_name(name)
      when :int
        Integer
      when :string
        String
      when :base64
        Base64
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

    def derived_from?(ancestor, child) # :nodoc:
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

    attr :spec
    attr :type
    attr :type_class
    attr :name

    def initialize(spec, type, name)
      @spec = spec
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

    def human_name(show_name=true)
      type_type = array? ? element_type.type.to_s : self.type.to_s
      str = array? ? (type_type + '[]') : type_type
      show_name ? (str + " " + name.to_s) : str
    end
  end

  class ArrayType < BaseType # :nodoc:
    attr :element_type

    def initialize(spec, element_type, name)
      super(spec, Array, name)
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
        i = -1
        @type_class.columns.each do |column|
          yield column.name, canonical_signature_entry(column.type, i += 1)
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

  class Base64 < String # :nodoc:
  end
end
