ActiveRecord::Base.logger = ActionController::Base.logger = ActionMailer::Base.logger = Logger.new("#{RAILS_ROOT}/log/production.log")
ActiveRecord::Base.establish_connection(:production)

ActionController::Base.consider_all_requests_local = false
ActionController::Base.reload_dependencies         = false 
ActiveRecord::Base.reload_associations             = false