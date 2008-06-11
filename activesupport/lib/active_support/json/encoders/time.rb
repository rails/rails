class Time
  # Returns a JSON string representing the time. If ActiveSupport.use_standard_json_time_format is set to true, the
  # ISO 8601 format is used.
  #
  # ==== Examples:
  #
  #   # With ActiveSupport.use_standard_json_time_format = true
  #   Time.utc(2005,2,1,15,15,10).to_json
  #   # => "2005-02-01T15:15:10Z"
  #
  #   # With ActiveSupport.use_standard_json_time_format = false
  #   Time.utc(2005,2,1,15,15,10).to_json
  #   # => "2005/02/01 15:15:10 +0000"
  def to_json(options = nil)
    if ActiveSupport.use_standard_json_time_format
      xmlschema.inspect
    else
      %("#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)}")
    end
  end
end
