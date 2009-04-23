class FalseClass
  def rails_to_json(options = nil) #:nodoc:
    'false'
  end

  alias to_json rails_to_json
end
