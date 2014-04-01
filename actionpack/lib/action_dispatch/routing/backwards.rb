module Rack # :nodoc:
  Mount = ActionDispatch::Routing::Router
  Mount::RouteSet = ActionDispatch::Routing::Router
  Mount::RegexpWithNamedGroups = ActionDispatch::Routing::Path
end
