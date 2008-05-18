class Time
  # Returns a JSON string representing the time.
  #
  # ==== Example:
  #   Time.utc(2005,2,1,15,15,10).to_json
  #   # => 2005/02/01 15:15:10 +0000"
  def to_json(options = nil)
    if ActiveSupport.use_standard_json_time_format
      xmlschema.inspect
    else
      %("#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)}")
    end
  end
end
