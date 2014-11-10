class Object
  # A duck-type assistant method. For example, Active Support extends Date
  # to define an <tt>acts_like?</tt> method that returns true when invoked
  # with the argument <tt>:date</tt>, and extends Time to define an
  # <tt>acts_like?</tt> that returns true when invoked with <tt>:time</tt>.
  # As a result, we can do <tt>x.acts_like?(:time)</tt> and
  # <tt>x.acts_like?(:date)</tt> to do duck-type-safe comparisons, since classes that
  # that we want to act like Time simply need to override the
  # <tt>acts_like?</tt> method.
  def acts_like?(duck_type)
    false
  end
end
