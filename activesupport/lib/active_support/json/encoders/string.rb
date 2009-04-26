class String
  private
    def rails_to_json(options = nil)
      ActiveSupport::JSON::Encoding.escape(self)
    end
end
