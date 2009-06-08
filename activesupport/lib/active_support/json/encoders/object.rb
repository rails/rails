class Object
  # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
  def to_json(options = nil)
    ActiveSupport::JSON.encode(as_json(options))
  end

  def as_json(options = nil)
    instance_values
  end
end
