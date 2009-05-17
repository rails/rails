class NilClass
  def rails_to_json(options = nil) #:nodoc:
    'null'
  end

  alias to_json rails_to_json
end
