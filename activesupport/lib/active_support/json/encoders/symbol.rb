class Symbol
  private
    def rails_to_json(options = nil)
      ActiveSupport::JSON.encode(to_s, options)
    end
end
