# frozen_string_literal: true

class Range
  # Returns the sole item in the range. If there are no items, or more
  # than one item, raises Enumerable::SoleItemExpectedError.
  #
  #   (1..1).sole   # => 1
  #   (2..1).sole   # => Enumerable::SoleItemExpectedError: no item found
  #   (..1).sole    # => Enumerable::SoleItemExpectedError: infinite range cannot represent a sole item
  def sole
    if self.begin.nil? || self.end.nil?
      raise ActiveSupport::EnumerableCoreExt::SoleItemExpectedError, "infinite range '#{inspect}' cannot represent a sole item"
    end

    super
  end
end
