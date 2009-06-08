class Time
  # Coerces the time to a string for JSON encoding.
  #
  # ISO 8601 format is used if ActiveSupport::JSON::Encoding.use_standard_json_time_format is set.
  #
  # ==== Examples
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
  #   Time.utc(2005,2,1,15,15,10).to_json
  #   # => "2005-02-01T15:15:10Z"
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
  #   Time.utc(2005,2,1,15,15,10).to_json
  #   # => "2005/02/01 15:15:10 +0000"
  def as_json(options = nil)
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      xmlschema
    else
      %(#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
    end
  end
end
