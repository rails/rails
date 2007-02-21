# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session from others.
  # Session data is stored in a cookie by default, so the data is hashed
  # with a secret to ensure its integrity.
  session :session_key => '_<%= app_name %>_session',
          :secret => '<%= CGI::Session.generate_unique_id(app_name) %>'
end
