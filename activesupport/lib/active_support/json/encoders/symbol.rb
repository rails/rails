class Symbol
  private
    def rails_to_json(*args)
      ActiveSupport::JSON.encode(to_s, *args)
    end
end
