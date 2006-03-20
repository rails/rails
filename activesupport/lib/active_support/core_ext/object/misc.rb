class Object #:nodoc:
  # A Ruby-ized realization of the K combinator, courtesy of Mikael Brockman.
  #
  #   def foo
  #     returning values = [] do
  #       values << 'bar'
  #       values << 'baz'
  #     end
  #   end
  #
  #   foo # => ['bar', 'baz']
  #
  #   def foo
  #     returning [] do |values|
  #       values << 'bar'
  #       values << 'baz'
  #     end
  #   end
  #
  #   foo # => ['bar', 'baz']
  #
  def returning(value)
    yield(value)
    value
  end

  def with_options(options)
    yield ActiveSupport::OptionMerger.new(self, options)
  end
  
  def to_json
    ActiveSupport::JSON.encode(self)
  end
end