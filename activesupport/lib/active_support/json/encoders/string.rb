class String
  private
    def rails_to_json(*)
      ActiveSupport::JSON::Encoding.escape(self)
    end
end
