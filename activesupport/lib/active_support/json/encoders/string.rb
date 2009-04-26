class String
  def rails_to_json(options = nil) #:nodoc:
    ActiveSupport::JSON::Encoding.escape(self)
  end
end
