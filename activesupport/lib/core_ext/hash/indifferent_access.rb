class HashWithIndifferentAccess < Hash
  def initialize(constructor)
    if constructor.is_a?(Hash)
      super()
      update(constructor.symbolize_keys)
    else
      super(constructor)
    end
  end
  
  alias_method :regular_read, :[]
  
  def [](key)
    case key
      when Symbol: regular_read(key) || regular_read(key.to_s)
      when String: regular_read(key) || regular_read(key.to_sym)
      else regular_read(key)
    end
  end

  alias_method :regular_writer, :[]=
  
  def []=(key, value)
    regular_writer(key.is_a?(String) ? key.to_sym : key, value)
  end
end

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module IndifferentAccess
        def with_indifferent_access
          HashWithIndifferentAccess.new(self)
        end
      end
    end
  end
end
