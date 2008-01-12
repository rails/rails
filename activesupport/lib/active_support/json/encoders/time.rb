class Time
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%Y/%m/%d %H:%M:%S")} #{utc_offset.to_utc_offset_s(false)}")
  end
end
