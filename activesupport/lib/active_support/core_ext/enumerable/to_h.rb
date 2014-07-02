unless Enumerable.method_defined?(:to_h)
  module Enumerable
    def to_h(*args)
      result = {}
      each(*args) do |pair|
        unless pair.is_a?(Array)
          raise TypeError.new("wrong element type #{pair.class.name} (expected array)")
        end
        unless pair.length == 2
          raise ArgumentError.new("element has wrong array length (expected 2, was #{pair.length})")
        end
        result[pair.first] = pair.last
      end
      result
    end
  end

  class Array
    def to_h
      result = {}
      each_with_index do |pair, i|
        unless pair.is_a?(Array)
          raise TypeError.new("wrong element type #{pair.class.name} at #{i} (expected array)")
        end
        unless pair.length == 2
          raise ArgumentError.new("wrong array length at #{i} (expected 2, was #{pair.length})")
        end
        result[pair.first] = pair.last
      end
      result
    end
  end

  class Hash
    def to_h
      if instance_of?(Hash)
        self
      else
        Hash[self]
      end
    end
  end

  class NilClass
    def to_h
      {}
    end
  end

  def ENV.to_h
    to_hash
  end
end
