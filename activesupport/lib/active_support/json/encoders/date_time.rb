class DateTime
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%m/%d/%Y %H:%M:%S %Z")}")
  end
end
