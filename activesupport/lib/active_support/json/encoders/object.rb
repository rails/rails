require 'active_support/core_ext/object/instance_variables'

class Object
  # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
  def to_json(options = nil)
    ActiveSupport::JSON.encode(self, options)
  end

  private
    def rails_to_json(*args)
      ActiveSupport::JSON.encode(instance_values, *args)
    end
end
