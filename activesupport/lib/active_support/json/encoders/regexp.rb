class Regexp
  def to_json(options = nil) #:nodoc:
    inspect
  end

  def as_json(options = nil) #:nodoc:
    self
  end
end
