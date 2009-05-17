class Numeric
  def rails_to_json(options = nil) #:nodoc:
    to_s
  end

  alias to_json rails_to_json
end
