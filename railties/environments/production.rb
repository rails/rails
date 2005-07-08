# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests, full error reports are disabled,
# and caching is turned on.

# Don't reload code; don't show full error reports; enable caching.
Dependencies.mechanism                             = :require
ActionController::Base.consider_all_requests_local = false
ActionController::Base.perform_caching             = true
