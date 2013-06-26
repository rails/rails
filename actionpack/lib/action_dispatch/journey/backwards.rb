module Rack # :nodoc:
  Mount = ActionDispatch::Journey::Router
  Mount::RouteSet = ActionDispatch::Journey::Router
  Mount::RegexpWithNamedGroups = ActionDispatch::Journey::Path::Pattern
end
