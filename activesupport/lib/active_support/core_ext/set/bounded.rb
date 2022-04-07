# frozen_string_literal: true

require "active_support/bounded_enumerable"

class Set
  def bound_at(n)
    ActiveSupport::BoundedEnumerable.new(self, n)
  end
end
