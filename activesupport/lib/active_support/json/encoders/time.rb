class Time
  def to_json(options = nil) #:nodoc:
    to_datetime.to_json(options)
  end
end
