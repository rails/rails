require 'action_controller'
require 'application_helper'

# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class AbstractApplicationController < ActionController::Base
  include ApplicationHelper
end