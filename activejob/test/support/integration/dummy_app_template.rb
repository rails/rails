if ENV['AJ_ADAPTER'] == 'delayed_job'
  generate "delayed_job:active_record", "--quiet"
  rake("db:migrate")
end

initializer 'activejob.rb', <<-CODE
require "#{File.expand_path("../jobs_manager.rb",  __FILE__)}"
JobsManager.current_manager.setup
CODE

initializer 'i18n.rb', <<-CODE
I18n.available_locales = [:en, :de]
CODE

file 'app/jobs/test_job.rb', <<-CODE
class TestJob < ActiveJob::Base
  queue_as :integration_tests

  def perform(x)
    File.open(Rails.root.join("tmp/\#{x}"), "w+") do |f|
      f.write I18n.locale
    end
  end
end
CODE
