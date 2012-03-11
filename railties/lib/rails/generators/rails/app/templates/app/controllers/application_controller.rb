class ApplicationController < ActionController::Base
  # prevent CSRF attacks by raising an exception,
  # if your application has an API, you'll probably need to use :reset_session
  protect_from_forgery :with => :exception
end
