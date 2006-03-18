# This implementation is HODEL-HASH-9600 compliant
class HashWithIndifferentAccess < Hash
  def initialize(constructor = {})
    if constructor.is_a?(Hash)
      super()
      update(constructor)
    else
      super(constructor)
    end
  end
 
  convert_key_and_hashes_and_call_super = lambda { |key, *args| super(convert_key(key), *args.map{|arg| convert_value(arg) }) }
  convert_other_hash_and_call_super     = lambda { |other_hash| super(convert_hash(other_hash)) }

  %w( [] []= fetch store delete has_key? include? key? member? ).each{ |method_name| define_method method_name, &convert_key_and_hashes_and_call_super }
  %w( == eql? replace initialize_copy merge merge! update      ).each{ |method_name| define_method method_name, &convert_other_hash_and_call_super     }

  def invert
    self.class.new.replace(super)
  end
  
  def values_at(*keys)
    super *keys.map{ |key| convert_key(key) }
  end

  protected
    def convert_key(key)
      key.kind_of?(Symbol) ? key.to_s : key
    end
    
    def convert_value(value)
      value.is_a?(Hash) ? value.with_indifferent_access : value
    end
    
    def convert_hash(hash)
      hash.is_a?(Hash) ? hash.inject({}){ |h,(k,v)| h[convert_key(k)] = convert_value(v); h } : hash
    end
end

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module IndifferentAccess #:nodoc:
        def with_indifferent_access
          HashWithIndifferentAccess.new(self)
        end
      end
    end
  end
end
