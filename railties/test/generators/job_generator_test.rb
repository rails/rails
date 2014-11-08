require 'generators/generators_test_helper'
require 'rails/generators/job/job_generator'

class JobGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(billing)

  def test_job_file_is_created
    run_generator

    assert_file "app/jobs/billing_job.rb" do |file|
      assert_match(/class BillingJob < ActiveJob::Base/, file)
      assert_match(/def perform\(\*args\)/, file)
      assert_match(/queue_as :default/, file)
    end
  end

  def test_job_test_case_is_created
    run_generator

    assert_file "test/jobs/billing_job_test.rb" do |file|
      assert_match(/class BillingJobTest < ActiveSupport::TestCase/, file)
    end
  end

  def test_queue_option
    run_generator ["billing", "--queue=high"]

    assert_file "app/jobs/billing_job.rb" do |file|
      assert_match(/queue_as :high/, file)
    end
  end

  def test_job_namespacing
    run_generator ["Book::Billing"]

    assert_file "app/jobs/book/billing_job.rb" do |file|
      assert_match(/class Book::BillingJob < ActiveJob::Base/, file)
    end

    assert_file "test/jobs/book/billing_job_test.rb" do |file|
      assert_match(/class Book::BillingJobTest < ActiveSupport::TestCase/, file)
    end
  end
end
