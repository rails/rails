class DateTime
  # Returns a JSON string representing the datetime.
  #
  # ==== Example:
  #   DateTime.civil(2005,2,1,15,15,10).to_json
  #   # => "2005/02/01 15:15:10 +0000"
  def to_json(options = nil)
    if ActiveSupport.use_standard_json_time_format
      xmlschema.inspect
    else
      strftime('"%Y/%m/%d %H:%M:%S %z"')
    end
  end
end
