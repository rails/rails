# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!

# Log error messages when you accidentally call methods on nil.
require 'active_support/whiny_nil'

# Don't reload code; show full error reports; disable caching.
Dependencies.mechanism                             = :require
ActionController::Base.consider_all_requests_local = true
ActionController::Base.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
ActionMailer::Base.delivery_method                 = :test
