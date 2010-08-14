class Object
  # Returns +value+ after yielding +value+ to the block. This simplifies the
  # process of constructing an object, performing work on the object, and then
  # returning the object from a method. It is a Ruby-ized realization of the K
  # combinator, courtesy of Mikael Brockman.
  #
  # ==== Examples
  #
  #  # Without returning
  #  def foo
  #    values = []
  #    values << "bar"
  #    values << "baz"
  #    return values
  #  end
  #
  #  foo # => ['bar', 'baz']
  #
  #  # returning with a local variable
  #  def foo
  #    returning values = [] do
  #      values << 'bar'
  #      values << 'baz'
  #    end
  #  end
  #
  #  foo # => ['bar', 'baz']
  #
  #  # returning with a block argument
  #  def foo
  #    returning [] do |values|
  #      values << 'bar'
  #      values << 'baz'
  #    end
  #  end
  #
  #  foo # => ['bar', 'baz']
  def returning(value)
    ActiveSupport::Deprecation.warn('Object#returning has been deprecated in favor of Object#tap.', caller)
    yield(value)
    value
  end
end