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
          self.enqueue_after_transaction_commit = false
        end
      RUBY

      assert_equal "false", rails("runner", "p FooJob.enqueue_after_transaction_commit").strip
    end

    test "custom serializers are loaded for Arguments#serialize" do
      app_file "config/initializers/custom_serializers.rb", <<~RUBY
        class Money; end

        class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
          def klass = Money
          def serialize(money) = {}
          def deserialize(hash) = Money.new
        end

        Rails.configuration.active_job.custom_serializers << MoneySerializer
      RUBY

      app "development"

      assert_equal([{}], ActiveJob::Arguments.serialize([Money.new]))
    end
  end
end
