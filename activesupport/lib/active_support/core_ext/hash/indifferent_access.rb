class HashWithIndifferentAccess < Hash
  def initialize(constructor = {})
    if constructor.is_a?(Hash)
      super()
      update(constructor.stringify_keys)
    else
      super(constructor)
    end
  end
  
  alias_method :regular_reader, :[] unless method_defined?(:regular_reader)
  
  def [](key)
    case key
      when Symbol: regular_reader(key.to_s) || regular_reader(key)
      when String: regular_reader(key) || regular_reader(key.to_sym)
      else regular_reader(key)
    end
  end

  alias_method :regular_writer, :[]= unless method_defined?(:regular_writer)
  
  def []=(key, value)
    regular_writer(key.is_a?(Symbol) ? key.to_s : key, value)
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
