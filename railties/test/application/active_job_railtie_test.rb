# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveJobRailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    test "jobs can set 'enqueue_after_transaction_commit' when eager_load is true" do
      add_to_env_config "development", "config.eager_load = true"

      app_file "app/jobs/foo_job.rb", <<-RUBY
        class FooJob < ActiveJob::Base
          self.enqueue_after_transaction_commit = :never
        end
      RUBY

      assert_equal ":never", rails("runner", "p FooJob.enqueue_after_transaction_commit").strip
    end
  end
end
