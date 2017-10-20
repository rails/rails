# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/job/job_generator"

class JobGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_job_skeleton_is_created
    run_generator ["refresh_counters"]
    assert_file "app/jobs/refresh_counters_job.rb" do |job|
      assert_match(/class RefreshCountersJob < ApplicationJob/, job)
    end
  end

  def test_job_queue_param
    run_generator ["refresh_counters", "--queue", "important"]
    assert_file "app/jobs/refresh_counters_job.rb" do |job|
      assert_match(/class RefreshCountersJob < ApplicationJob/, job)
      assert_match(/queue_as :important/, job)
    end
  end

  def test_job_namespace
    run_generator ["admin/refresh_counters", "--queue", "admin"]
    assert_file "app/jobs/admin/refresh_counters_job.rb" do |job|
      assert_match(/class Admin::RefreshCountersJob < ApplicationJob/, job)
      assert_match(/queue_as :admin/, job)
    end
  end

  def test_application_job_skeleton_is_created
    run_generator ["refresh_counters"]
    assert_file "app/jobs/application_job.rb" do |job|
      assert_match(/class ApplicationJob < ActiveJob::Base/, job)
    end
  end
end
