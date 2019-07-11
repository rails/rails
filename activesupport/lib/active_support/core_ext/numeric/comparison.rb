# frozen_string_literal: true

class Numeric
  # 2.less?(3) # => true
  def less?(other)
    self < other
  end

  # 5.less_or_equal?(5) # => true
  def less_or_equal?(other)
    self <= other
  end

  # 3.greater?(2) #=> true
  def greater?(other)
    self > other
  end

  # 3.greater_or_equal?(3) # => true
  def greater_or_equal?(other)
    self >= other
  end
end
