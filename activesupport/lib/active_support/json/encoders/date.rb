class Date
  def to_json #:nodoc:
    %("#{strftime("%m/%d/%Y")}")
  end
end
