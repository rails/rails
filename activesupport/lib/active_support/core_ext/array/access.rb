class Array
  # Returns the tail of the array from +position+.
  #
  #   %w( a b c d ).from(0)  # => ["a", "b", "c", "d"]
  #   %w( a b c d ).from(2)  # => ["c", "d"]
  #   %w( a b c d ).from(10) # => []
  #   %w().from(0)           # => []
  def from(position)
    self[position, length] || []
  end

  # Returns the beginning of the array up to +position+.
  #
  #   %w( a b c d ).to(0)  # => ["a"]
  #   %w( a b c d ).to(2)  # => ["a", "b", "c"]
  #   %w( a b c d ).to(10) # => ["a", "b", "c", "d"]
  #   %w().to(0)           # => []
  def to(position)
    first position + 1
  end

  # Equal to <tt>self[0] = value</tt>.
  #
  #   a = [*1..5]
  #   a.first = 0
  # Now `a` is [0, 2, 3, 4, 5]
  def first=(value)
    self[0] = value
  end

  # Equal to <tt>self[1]</tt>.
  #
  #   %w( a b c d e ).second # => "b"
  def second
    self[1]
  end

  # Equal to <tt>self[1] = value</tt>.
  #
  #   a = [*1..5]
  #   a.second = 0
  # Now `a` is [1, 0, 3, 4, 5]
  def second=(value)
    self[1] = value
  end

  # Equal to <tt>self[2]</tt>.
  #
  #   %w( a b c d e ).third # => "c"
  def third
    self[2]
  end

  # Equal to <tt>self[2] = value</tt>.
  #
  #   a = [*1..5]
  #   a.third = 0
  # Now `a` is [1, 2, 0, 4, 5]
  def third=(value)
    self[2] = value
  end

  # Equal to <tt>self[3]</tt>.
  #
  #   %w( a b c d e ).fourth # => "d"
  def fourth
    self[3]
  end

  # Equal to <tt>self[3] = value</tt>.
  #
  #   a = [*1..5]
  #   a.fourth = 0
  # Now `a` is [1, 2, 3, 0, 5]
  def fourth=(value)
    self[3] = value
  end

  # Equal to <tt>self[4]</tt>.
  #
  #   %w( a b c d e ).fifth # => "e"
  def fifth
    self[4]
  end

  # Equal to <tt>self[4] = value</tt>.
  #
  #   a = [*1..5]
  #   a.fifth = 0
  # Now `a` is [1, 2, 3, 4, 0]
  def fifth=(value)
    self[4] = value
  end

  # Equal to <tt>self[41]</tt>. Also known as accessing "the reddit".
  def forty_two
    self[41]
  end

  # Equal to <tt>self[41] = value</tt>.
  #
  #   a = [*1..42]
  #   a.forty_two = 0
  # Now `a` is [1, 2, ... 40, 41, 0]
  def forty_two=(value)
    self[41] = value
  end

  # Set last element value
  #
  #   a = [*1..7]
  #   a.last = 0
  # Now `a` is [1, 2, 3, 4, 5, 6, 0]
  def last=(value)
    self[length - 1] = value
  end
end
