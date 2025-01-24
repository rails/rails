# frozen_string_literal: true

class Range
  # Returns the sole item in the range. If there are no items, or more
  # than one item, raises Enumerable::SoleItemExpectedError.
  #
  #   (1..1).sole   # => 1
  #   (2..1).sole   # => Enumerable::SoleItemExpectedError: no item found
  #   (..1).sole    # => Enumerable::SoleItemExpectedError: multiple items found
  def sole
    if self.begin.nil? || self.end.nil?
      raise ActiveSupport::EnumerableCoreExt::SoleItemExpectedError, "multiple items found"
    end

    super
  end
end
