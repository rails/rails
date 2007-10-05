class DateTime
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%Y/%m/%d %H:%M:%S %z")}")
  end
end
