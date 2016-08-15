if ENV["AJ_ADAPTER"] == "delayed_job"
  generate "delayed_job:active_record", "--quiet"
end

rails_command("db:migrate")

initializer "activejob.rb", <<-CODE
require "#{File.expand_path("../jobs_manager.rb",  __FILE__)}"
JobsManager.current_manager.setup
CODE

initializer "i18n.rb", <<-CODE
I18n.available_locales = [:en, :de]
CODE

file "app/jobs/test_job.rb", <<-CODE
class TestJob < ActiveJob::Base
  queue_as :integration_tests

  def perform(x)
    File.open(Rails.root.join("tmp/\#{x}"), "wb+") do |f|
      f.write Marshal.dump({
        "locale" => I18n.locale.to_s || "en",
        "executed_at" => Time.now.to_r
      })
    end
  end
end
CODE
