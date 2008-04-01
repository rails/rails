class Date
  # Returns a JSON string representing the date.
  #
  # ==== Example:
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
