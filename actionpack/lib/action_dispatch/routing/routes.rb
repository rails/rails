# A singleton that stores the current route set
ActionDispatch::Routing::Routes = ActionDispatch::Routing::RouteSet.new

# To preserve compatibility with pre-3.0 Rails action_controller/deprecated.rb
# defines ActionDispatch::Routing::Routes as an alias
