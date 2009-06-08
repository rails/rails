class String
  def to_json(options = nil) #:nodoc:
    ActiveSupport::JSON::Encoding.escape(self)
  end

  def as_json(options = nil) #:nodoc:
    self
  end
end
