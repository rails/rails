class Symbol
  def to_json(options = nil) #:nodoc:
    ActiveSupport::JSON.encode(to_s, options)
  end
end
