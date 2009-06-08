class Date
  # Coerces the date to a string for JSON encoding.
  #
  # ISO 8601 format is used if ActiveSupport::JSON::Encoding.use_standard_json_time_format is set.
  #
  # ==== Examples
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
  #   Date.new(2005,2,1).to_json
  #   # => "2005-02-01"
  #
  #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
  #   Date.new(2005,2,1).to_json
  #   # => "2005/02/01"
  def as_json(options = nil)
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      strftime("%Y-%m-%d")
    else
      strftime("%Y/%m/%d")
    end
  end
end
