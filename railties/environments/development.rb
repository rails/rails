ActionController::Base.consider_all_requests_local = true
ActionController::Base.reload_dependencies         = true
ActiveRecord::Base.reload_associations             = true

require 'breakpoint'
require 'irb/completion'
# Change the port (default: 42531) here in case you are
# on shared hosting. Note that you should set up a SSH
# tunnel when you want to connect from a different
# computer over the internet. See the documentation of
# Breakpoint.activate_drb for how to do that.
Breakpoint.activate_drb('druby://localhost:42531', nil)