class Object
  # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
  def rails_to_json(options = nil)
    ActiveSupport::JSON.encode(instance_values, options)
  end

  def to_json(*args)
    rails_to_json(*args)
  end
end
