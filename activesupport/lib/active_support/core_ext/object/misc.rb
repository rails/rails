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

  # A duck-type assistant method. For example, ActiveSupport extends Date
  # to define an acts_like_date? method, and extends Time to define
  # acts_like_time?. As a result, we can do "x.acts_like?(:time)" and
  # "x.acts_like?(:date)" to do duck-type-safe comparisons, since classes that
  # we want to act like Time simply need to define an acts_like_time? method.
  def acts_like?(duck)
    respond_to? :"acts_like_#{duck}?"
  end
end