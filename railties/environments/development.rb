ActionController::Base.consider_all_requests_local = true
ActionController::Base.reload_dependencies         = true
ActiveRecord::Base.reload_associations             = true

BREAKPOINT_SERVER_PORT = 42531