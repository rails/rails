# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.

# Log error messages when you accidentally call methods on nil.
require 'active_support/whiny_nil'

# Reload code; show full error reports; disable caching.
Dependencies.mechanism                             = :load
ActionController::Base.consider_all_requests_local = true
ActionController::Base.perform_caching             = false

# The breakpoint server port that script/breakpointer connects to.
BREAKPOINT_SERVER_PORT = 42531
