class DateTime
  # Coerces the datetime to a string for JSON encoding.
  #
  # ISO 8601 format is used if ActiveSupport::JSON::Encoding.use_standard_json_time_format is set.
  #
  # ==== Examples
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
  #   DateTime.civil(2005,2,1,15,15,10).to_json
  #   # => "2005-02-01T15:15:10+00:00"
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
  #   DateTime.civil(2005,2,1,15,15,10).to_json
  #   # => "2005/02/01 15:15:10 +0000"
  def as_json(options = nil)
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      xmlschema
    else
      strftime('%Y/%m/%d %H:%M:%S %z')
    end
  end
end
