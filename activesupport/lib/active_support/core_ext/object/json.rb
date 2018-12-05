# frozen_string_literal: true

# Hack to load json gem first so we can overwrite its to_json.
require "json"
require "bigdecimal"
require "uri/generic"
require "pathname"
require "active_support/core_ext/big_decimal/conversions" # for #to_s
require "active_support/core_ext/hash/except"
require "active_support/core_ext/hash/slice"
require "active_support/core_ext/object/instance_variables"
require "time"
require "active_support/core_ext/time/conversions"
require "active_support/core_ext/date_time/conversions"
require "active_support/core_ext/date/conversions"
require "active_support/json/as_json_encoder"

#--
# The JSON gem adds a few modules to Ruby core classes containing :to_json definition, overwriting
# their default behavior. That said, we need to define the basic to_json method in all of them,
# otherwise they will always use to_json gem implementation, which is backwards incompatible in
# several cases (for instance, the JSON implementation for Hash does not work) with inheritance
# and consequently classes as ActiveSupport::OrderedHash cannot be serialized to json.
#
# On the other hand, we should avoid conflict with ::JSON.{generate,dump}(obj). Unfortunately, the
# JSON gem's encoder relies on its own to_json implementation to encode objects. Since it always
# passes a ::JSON::State object as the only argument to to_json, we can detect that and forward the
# calls to the original to_json method.
#
# It should be noted that when using ::JSON.{generate,dump} directly, ActiveSupport's encoder is
# bypassed completely. This means that as_json won't be invoked and the JSON gem will simply
# ignore any options it does not natively understand. This also means that ::JSON.{generate,dump}
# should give exactly the same results with or without active support.

module ActiveSupport
  module ToJsonWithActiveSupportEncoder # :nodoc:
    def to_json(options = nil)
      if options.is_a?(::JSON::State)
        # Called from JSON.{generate,dump}, forward it to JSON gem's to_json
        super(options)
      else
        # to_json is being invoked directly, use ActiveSupport's encoder
        ActiveSupport::JSON.encode(self, options)
      end
    end
  end

  module AsJSON
    def as_json(options = nil)
      ActiveSupport::JSON::AsJSONEncoder.encode_next self, options
    end
  end
end

[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass, Enumerable].reverse_each do |klass|
  klass.prepend(ActiveSupport::ToJsonWithActiveSupportEncoder)
end

class Object
  include ActiveSupport::AsJSON
end
