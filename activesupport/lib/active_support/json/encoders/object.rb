class Object
  # Dumps object in JSON (JavaScript Object Notation).  See www.json.org for more info.
  #
  #   Account.find(1).to_json
  #   => "{attributes: {username: \"foo\", id: \"1\", password: \"bar\"}}"
  #
  def to_json
    ActiveSupport::JSON.encode(instance_values)
  end
end
