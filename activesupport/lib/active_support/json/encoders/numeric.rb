class Numeric
  def to_json(options = nil) #:nodoc:
    to_s
  end

  def as_json(options = nil) #:nodoc:
    self
  end
end

class Float
  def to_json(options = nil) #:nodoc:
    to_s
  end
end

class Integer
  def to_json(options = nil) #:nodoc:
    to_s
  end
end
