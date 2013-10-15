require 'yaml'

YAML.add_builtin_type("omap") do |type, val|
  ActiveSupport::OrderedHash[val.map(&:to_a).map(&:first)]
end

# OrderedHash is namespaced to prevent conflicts with other implementations
module ActiveSupport
  class OrderedHash < ::Hash #:nodoc:
  end
end
