require 'test_helper'
require 'action_controller/performance_test'

ActionController::Base.perform_caching = true
ActionView::Base.cache_template_loading = true
ActiveSupport::Dependencies.mechanism = :require
Rails.logger.level = ActiveSupport::BufferedLogger::INFO
