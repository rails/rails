$:.unshift(File.dirname(__FILE__))

require 'action_controller/support/clean_logger'

require 'action_controller/base'
require 'action_controller/rescue'
require 'action_controller/benchmarking'
require 'action_controller/filters'
require 'action_controller/layout'
require 'action_controller/flash'
require 'action_controller/scaffolding'
require 'action_controller/cgi_process'

ActionController::Base.class_eval { 
  include ActionController::Rescue
  include ActionController::Benchmarking
  include ActionController::Filters
  include ActionController::Layout
  include ActionController::Flash
  include ActionController::Scaffolding
}

require 'action_view'
ActionController::Base.template_class = ActionView::ERbTemplate