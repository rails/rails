class DateTime
  def to_json #:nodoc:
    %("#{strftime("%m/%d/%Y %H:%M:%S %Z")}")
  end
end
