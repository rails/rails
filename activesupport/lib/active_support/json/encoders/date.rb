class Date
  def to_json(options = nil) #:nodoc:
    %("#{strftime("%m/%d/%Y")}")
  end
end
