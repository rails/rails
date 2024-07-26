require File.dirname(__FILE__) + "/shared"

ActiveRecord::Base.logger = ActionController::Base.logger = ActionMailer::Base.logger =
  Logger.new(File.dirname(__FILE__) + "/../../log/test.log")

ActiveRecord::Base.establish_connection(database_configurations["test"])
