require 'active_support/core_ext/object/instance_variables'

class Object
  # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
  def rails_to_json(options = {})
    ActiveSupport::JSON.encode(instance_values, options)
  end

  alias to_json rails_to_json
end
