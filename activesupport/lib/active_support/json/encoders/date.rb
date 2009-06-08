class Date
  # Returns a JSON string representing the date. If ActiveSupport.use_standard_json_time_format is set to true, the
  # ISO 8601 format is used.
  #
  # ==== Examples
  #
  #   # With ActiveSupport.use_standard_json_time_format = true
  #   Date.new(2005,2,1).to_json
  #   # => "2005-02-01"
  #
  #   # With ActiveSupport.use_standard_json_time_format = false
  #   Date.new(2005,2,1).to_json
  #   # => "2005/02/01"
  def to_json(options = nil)
    if ActiveSupport.use_standard_json_time_format
      %("#{strftime("%Y-%m-%d")}")
    else
      %("#{strftime("%Y/%m/%d")}")
    end
  end
end
