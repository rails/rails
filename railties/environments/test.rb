ActiveRecord::Base.logger = ActionController::Base.logger = ActionMailer::Base.logger = Logger.new("#{RAILS_ROOT}/log/test.log")
ActiveRecord::Base.establish_connection(:test)
