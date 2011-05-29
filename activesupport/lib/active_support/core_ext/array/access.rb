class Array
  # Returns the tail of the array from +position+.
  #
  #   %w( a b c d ).from(0)  # => %w( a b c d )
  #   %w( a b c d ).from(2)  # => %w( c d )
  #   %w( a b c d ).from(10) # => %w()
  #   %w().from(0)           # => %w()
  def from(position)
    self[position, length] || []
  end

  # Returns the beginning of the array up to +position+.
  #
  #   %w( a b c d ).to(0)  # => %w( a )
  #   %w( a b c d ).to(2)  # => %w( a b c )
  #   %w( a b c d ).to(10) # => %w( a b c d )
  #   %w().to(0)           # => %w()
  def to(position)
    self.first position + 1
  end

  # Equal to <tt>self[1]</tt>.
  def second
    self[1]
  end

  # Equal to <tt>self[2]</tt>.
  def third
    self[2]
  end

  # Equal to <tt>self[3]</tt>.
  def fourth
    self[3]
  end

  # Equal to <tt>self[4]</tt>.
  def fifth
    self[4]
  end

  # Equal to <tt>self[41]</tt>. Also known as accessing "the reddit".
  def forty_two
    self[41]
  end
end
