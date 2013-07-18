require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/object/acts_like'

class Range #:nodoc:

  def each_with_time_with_zone(&block)
    ensure_iteration_allowed
    each_without_time_with_zone(&block)
  end
  alias_method_chain :each, :time_with_zone

  def step_with_time_with_zone(n = 1, &block)
    ensure_iteration_allowed
    step_without_time_with_zone(n, &block)
  end
  alias_method_chain :step, :time_with_zone

  private
  def ensure_iteration_allowed
    if first.acts_like?(:time)
      raise TypeError, "can't iterate from #{first.class}"
    end
  end
end
