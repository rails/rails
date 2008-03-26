class Object
  # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
  def to_json(options = {})
    ActiveSupport::JSON.encode(instance_values, options)
  end
end
