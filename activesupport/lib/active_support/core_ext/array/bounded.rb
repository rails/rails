# frozen_string_literal: true

require "active_support/bounded_enumerable"

class Array
  def bound_at(n)
    ActiveSupport::BoundedEnumerable.new(self, n)
  end
end
