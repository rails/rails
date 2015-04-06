class Range #:nodoc:

  def each_with_time_with_zone(&block)
    ensure_iteration_allowed
    each_without_time_with_zone(&block)
  end
  # TODO: change to Module#prepend as soon as the fix is backported to MRI 2.2:
  # https://bugs.ruby-lang.org/issues/10847
  alias_method :each_without_time_with_zone, :each
  alias_method :each, :each_with_time_with_zone

  def step_with_time_with_zone(n = 1, &block)
    ensure_iteration_allowed
    step_without_time_with_zone(n, &block)
  end
  # TODO: change to Module#prepend as soon as the fix is backported to MRI 2.2:
  # https://bugs.ruby-lang.org/issues/10847
  alias_method :step_without_time_with_zone, :step
  alias_method :step, :step_with_time_with_zone

  private
  def ensure_iteration_allowed
    if first.is_a?(Time)
      raise TypeError, "can't iterate from #{first.class}"
    end
  end
end
