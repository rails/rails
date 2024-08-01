# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveJobAdapterTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      @old = ENV["PARALLEL_WORKERS"]
      ENV["PARALLEL_WORKERS"] = "0"

      build_app
    end

    def teardown
      ENV["PARALLEL_WORKERS"] = @old

      teardown_app
    end

    test "config set via application.rb" do
      add_to_config "config.active_job.queue_adapter = :inline"
      make_inline_test_file
      assert_successful_test_run "integration/config_test.rb"
    end

    test "config set via environment config" do
      add_to_config "config.active_job.queue_adapter = :async"
      app_file "config/environments/test.rb", <<-RUBY
        Rails.application.configure do
          config.active_job.queue_adapter = :inline
        end
      RUBY
      make_inline_test_file
      assert_successful_test_run "integration/config_test.rb"
    end

    test "config is set for production, but test uses defaults" do
      app_file "config/environments/production.rb", <<-RUBY
        Rails.application.configure do
          config.active_job.queue_adapter = :sidekiq
        end
      RUBY
      make_test_test_file
      assert_successful_test_run "integration/config_test.rb"
    end

    private
      def make_inline_test_file
        app_file "test/integration/config_test.rb", <<-RUBY
        require "test_helper"

        class RailsConfigUnitTest < ActiveSupport::TestCase
          test "the Inline Active Job adapter is used in unit tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigIntegrationTest < ActionDispatch::IntegrationTest
          test "the Inline Active Job adapter is used in integration tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter

            # ActionDispatch::IntegrationTest includes ActiveJob::TestHelper,
            # which adds a bunch of assertions. But these assertions only work
            # if the test adapter is TestAdapter. So for other test adapters,
            # we raise an error if the method is called.
            assert_raise ArgumentError, "assert_enqueued_jobs requires the Active Job test adapter, you're using ActiveJob::QueueAdapters::InlineAdapter" do
              assert_no_enqueued_jobs {}
            end
          end
        end

        class RailsConfigJobTest < ActiveJob::TestCase
          test "the Inline Active Job adapter is used in job tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter

            # ActiveJob::TesTCase includes ActiveJob::TestHelper,
            # which adds a bunch of assertions. But these assertions only work
            # if the test adapter is TestAdapter. So for other test adapters,
            # we raise an error if the method is called.
            assert_raise ArgumentError, "assert_enqueued_jobs requires the Active Job test adapter, you're using ActiveJob::QueueAdapters::InlineAdapter" do
              assert_no_enqueued_jobs {}
            end
          end
        end

        class RailsConfigMailerTest < ActionMailer::TestCase
          test "the Inline Active Job adapter is used in mailer tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter

            # ActionMailer::TestHelper includes ActiveJob::TestHelper
            # So this just asserts that we haven't broken Action Mailer assertions that
            # depend on Active Job:
            assert_emails(0) {}
            assert_emails(0)
          end
        end

        class RailsConfigHelperTest < ActionView::TestCase
          test "the Inline Active Job adapter is used in helper tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigControllerTest < ActionController::TestCase
          test "the Inline Active Job adapter is used in controller tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigSystemTest < ActionDispatch::SystemTestCase
          test "the Inline Active Job adapter is used in system tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter), adapter
            assert_equal :inline, Rails.application.config.active_job.queue_adapter
          end
        end
        RUBY
      end

      def make_test_test_file
        app_file "test/integration/config_test.rb", <<-RUBY
        require "test_helper"

        class RailsConfigUnitTest < ActiveSupport::TestCase
          test "the Test Active Job adapter is used in unit tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigIntegrationTest < ActionDispatch::IntegrationTest
          test "the Test Active Job adapter is used in integration tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter

            assert_nothing_raised do
              assert_no_enqueued_jobs {}
            end
          end
        end

        class RailsConfigJobTest < ActiveJob::TestCase
          test "the Test Active Job adapter is used in job tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter

            assert_nothing_raised do
              assert_no_enqueued_jobs {}
            end
          end
        end

        class RailsConfigMailerTest < ActionMailer::TestCase
          test "the Test Active Job adapter is used in mailer tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter

            assert_emails(0) {}
            assert_emails(0)
          end
        end

        class RailsConfigHelperTest < ActionView::TestCase
          test "the Test Active Job adapter is used in helper tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigControllerTest < ActionController::TestCase
          test "the Test Active Job adapter is used in controller tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter
          end
        end

        class RailsConfigSystemTest < ActionDispatch::SystemTestCase
          test "the Test Active Job adapter is used in system tests" do
            adapter = ActiveJob::Base.queue_adapter
            assert adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter), adapter
            assert_equal :test, Rails.application.config.active_job.queue_adapter
          end
        end
        RUBY
      end

      def assert_successful_test_run(name)
        result = run_test_file(name)
        assert_equal 0, $?.to_i, result
        result
      end

      def run_test_file(name)
        rails "test", "#{app_path}/test/#{name}", allow_failure: true
      end
  end
end
