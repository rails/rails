class Time
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)}")
  end
end
