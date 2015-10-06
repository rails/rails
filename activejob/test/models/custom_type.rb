class CustomType
  # Enable custom serialization for this class
  include ActiveJob::Serialization
  # Some attributes to serialize
  attr_reader :foo, :bar

  def initialize(v1, v2)
    @foo = v1
    @bar = v2
  end

  # equality method used in tests
  def ==(obj)
    obj.is_a?(CustomType) && obj.foo == foo && obj.bar == bar
  end

  # Simplest implementation of serialization interface
  class << self

    def aj_dump(value)
      Marshal.dump(value)
    end

    def aj_load(value)
      Marshal.load(value)
    end

  end

end