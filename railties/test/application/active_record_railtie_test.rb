# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveRecordRailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    test "continuable jobs raise when checkpointing in a transaction" do
      app_file "app/jobs/continuable_job.rb", <<~RUBY
        require "active_job/continuable"

        class ContinuableJob < ActiveJob::Base
          include ActiveJob::Continuable

          def perform(*)
            step :checkpoint_in_transaction do |step|
              ActiveRecord::Base.transaction do
                step.checkpoint!
              end
            end
          end
        end
      RUBY

      exception = assert_raises do
        rails("runner", "ContinuableJob.perform_now")
      end
      assert_includes exception.message, "ActiveJob::Continuation::CheckpointError: Cannot checkpoint job with open transactions"
    end

    test "filter_attributes include filter_parameters" do
      app "development"

      assert_not_includes ActiveRecord::Base.filter_attributes, "special_param"

      Rails.application.config.filter_parameters += [ :special_param ]

      assert_includes ActiveRecord::Base.filter_attributes, "special_param"
    end

    test "filter_paramenters include filter_attributes for ActiveRecord::Base" do
      app "development"

      assert_not_includes ActiveRecord::Base.filter_attributes, "special_attr"

      ActiveRecord::Base.filter_attributes += [ :special_attr ]

      assert_includes Rails.application.config.filter_parameters, "special_attr"
    end

    test "filter_paramenters include filter_attributes for AR::Base subclasses" do
      app "development"

      assert_not_includes ActiveRecord::Base.filter_attributes, "special_attr"

      Message.filter_attributes += [ :special_attr ]

      assert_includes Rails.application.config.filter_parameters, "message.special_attr"
    end
  end
end
