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
  end
end
