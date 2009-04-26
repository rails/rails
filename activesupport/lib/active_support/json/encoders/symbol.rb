class Symbol
  def rails_to_json(options = nil) #:nodoc:
    ActiveSupport::JSON.encode(to_s, options)
  end
end
