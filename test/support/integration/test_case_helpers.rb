require 'active_support/concern'
require 'support/integration/jobs_manager'

module TestCaseHelpers
  extend ActiveSupport::Concern

  included do
    self.use_transactional_fixtures = false

    setup do
      clear_jobs
    end

    teardown do
      clear_jobs
      FileUtils.rm_rf Dir[Dummy::Application.root.join("tmp/AJ-*")]
    end
  end

  protected

    def jobs_manager
      JobsManager.current_manager
    end

    def clear_jobs
      jobs_manager.clear_jobs
    end

end
