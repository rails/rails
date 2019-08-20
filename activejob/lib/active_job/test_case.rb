# frozen_string_literal: true

require "active_support/test_case"

module ActiveJob
  class TestCase < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    ActiveSupport.run_load_hooks(:active_job_test_case, self)
  end
end
