# Hack to load json gem first so we can overwrite its to_json.
require 'json'
require 'bigdecimal'

# The JSON gem adds a few modules to Ruby core classes containing :to_json definition, overwriting
# their default behavior. That said, we need to define the basic to_json method in all of them,
# otherwise they will always use to_json gem implementation, which is backwards incompatible in
# several cases (for instance, the JSON implementation for Hash does not work) with inheritance
# and consequently classes as ActiveSupport::OrderedHash cannot be serialized to json.
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
    def to_json(options = nil)
      ActiveSupport::JSON.encode(self, options)
    end
  end
end

class Object
  def as_json(options = nil) #:nodoc:
    if respond_to?(:to_hash)
      to_hash
    else
      instance_values
    end
  end
end

class Struct #:nodoc:
  def as_json(options = nil)
    Hash[members.zip(values)]
  end
end

class TrueClass
  def as_json(options = nil) #:nodoc:
    self
  end

  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class FalseClass
  def as_json(options = nil) #:nodoc:
    self
  end

  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class NilClass
  def as_json(options = nil) #:nodoc:
    self
  end

  def encode_json(encoder) #:nodoc:
    'null'
  end
end

class String
  def as_json(options = nil) #:nodoc:
    self
  end

  def encode_json(encoder) #:nodoc:
    encoder.escape(self)
  end
end

class Symbol
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Numeric
  def as_json(options = nil) #:nodoc:
    self
  end

  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class Float
  # Encoding Infinity or NaN to JSON should return "null". The default returns
  # "Infinity" or "NaN" which breaks parsing the JSON. E.g. JSON.parse('[NaN]').
  def as_json(options = nil) #:nodoc:
    finite? ? self : nil
  end
end

class BigDecimal
  # A BigDecimal would be naturally represented as a JSON number. Most libraries,
  # however, parse non-integer JSON numbers directly as floats. Clients using
  # those libraries would get in general a wrong number and no way to recover
  # other than manually inspecting the string with the JSON code itself.
  #
  # That's why a JSON string is returned. The JSON literal is not numeric, but
  # if the other end knows by contract that the data is supposed to be a
  # BigDecimal, it still has the chance to post-process the string and get the
  # real value.
  #
  # Use <tt>ActiveSupport.use_standard_json_big_decimal_format = true</tt> to
  # override this behavior.
  def as_json(options = nil) #:nodoc:
    if finite?
      ActiveSupport.encode_big_decimal_as_string ? to_s : self
    else
      nil
    end
  end
end

class Regexp
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

module Enumerable
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Range
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    # use encoder as a proxy to call as_json on all elements, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::Encoder.new(options)
    map { |v| encoder.as_json(v, options) }
  end

  def encode_json(encoder) #:nodoc:
    # we assume here that the encoder has already run as_json on self and the elements, so we run encode_json directly
    "[#{map { |v| v.encode_json(encoder) } * ','}]"
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    # use encoder as a proxy to call as_json on all values in the subset, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::Encoder.new(options)
    Hash[subset.map { |k, v| [k.to_s, encoder.as_json(v, options)] }]
  end

  def encode_json(encoder) #:nodoc:
    # values are encoded with use_options = false, because we don't want hash representations from ActiveModel to be
    # processed once again with as_json with options, as this could cause unexpected results (i.e. missing fields);

    # on the other hand, we need to run as_json on the elements, because the model representation may contain fields
    # like Time/Date in their original (not jsonified) form, etc.

    "{#{map { |k,v| "#{encoder.encode(k.to_s)}:#{encoder.encode(v, false)}" } * ','}}"
  end
end

class Time
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      %(#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
    end
  end
end

class Date
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      strftime("%Y-%m-%d")
    else
      strftime("%Y/%m/%d")
    end
  end
end

class DateTime
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      strftime('%Y/%m/%d %H:%M:%S %z')
    end
  end
end

class Process::Status
  def as_json(options = nil)
    { :exitstatus => exitstatus, :pid => pid }
  end
end
