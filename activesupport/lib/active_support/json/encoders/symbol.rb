class Symbol
  def rails_to_json(options = {}) #:nodoc:
    ActiveSupport::JSON.encode(to_s, options)
  end

  alias to_json rails_to_json
end
