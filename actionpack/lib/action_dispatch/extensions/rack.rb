# Monkey patch in new test helper methods
unless Rack::Utils.respond_to?(:build_nested_query)
  require 'action_dispatch/extensions/rack/mock'
  require 'action_dispatch/extensions/rack/utils'
end
