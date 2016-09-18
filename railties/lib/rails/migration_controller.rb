require "rails/application_controller"

class Rails::MigrationController < Rails::ApplicationController # :nodoc:
  before_action :require_local!

  def migrate
    require 'rake'
    Rake::Task.clear
    Rails.application.load_tasks
    Rake::Task['db:migrate'].invoke
    redirect_to "/"
  ensure
    Rake::Task.clear
  end
end
