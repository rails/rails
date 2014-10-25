module RangeSupportingTimeWithZone #:nodoc:

  def each(&block)
    ensure_iteration_allowed
    super(&block)
  end

  def step(n = 1, &block)
    ensure_iteration_allowed
    super(n, &block)
  end

  private
  def ensure_iteration_allowed
    if first.is_a?(Time)
      raise TypeError, "can't iterate from #{first.class}"
    end
  end
end

Range.prepend(RangeSupportingTimeWithZone)
