require 'yaml'

YAML.add_builtin_type("omap") do |type, val|
  ActiveSupport::OrderedHash[val.map(&:to_a).map(&:first)]
end

ActiveSupport::OrderedHash = Hash
