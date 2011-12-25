require "active_support/multibyte"

class String
  def at(position)
    self[position]
  end

  def from(position)
    self[position..-1]
  end

  def to(position)
    self[0..position]
  end

  def first(limit = 1)
    if limit == 0
      ''
    elsif limit >= size
      self
    else
      to(limit - 1)
    end
  end

  def last(limit = 1)
    if limit == 0
      ''
    elsif limit >= size
      self
    else
      from(-limit)
    end
  end
end
