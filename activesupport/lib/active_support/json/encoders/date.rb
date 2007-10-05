class Date
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%Y/%m/%d")}")
  end
end
