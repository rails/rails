# Hack to load json gem first so we can overwrite its to_json.
begin
  require 'json'
rescue LoadError
end

# The JSON gem adds a few modules to Ruby core classes containing :to_json definition, overwriting
# their default behavior. That said, we need to define the basic to_json method in all of them,
# otherwise they will always use to_json gem implementation, which is backwards incompatible in
# several cases (for instance, the JSON implementation for Hash does not work) with inheritance
# and consequently classes as ActiveSupport::OrderedHash cannot be serialized to json.
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
    def to_json(options = nil)
      ActiveSupport::JSON.encode(self, options)
    end
  end
end

module Process
  class Status
    def as_json(options = nil)
      { :exitstatus => exitstatus, :pid => pid }
    end
  end
end
