# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # If you're using the Cookie Session Store you can leave out the :secret
  protect_from_forgery :secret => '<%= app_secret %>'
end