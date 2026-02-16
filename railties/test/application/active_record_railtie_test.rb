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
      app_file "config/initializers/parameter_filter.rb", <<~RUBY
        Rails.application.config.filter_parameters += [ :special_param ]
      RUBY
      app "development"

      assert_includes ActiveRecord::Base.filter_attributes, :special_param
    end

    test "filter_parameters include filter_attributes for an AR::Base subclass" do
      app "development"

      assert_not_includes ActiveRecord::Base.filter_attributes, "message.special_attr"

      class Message < ActiveRecord::Base
        self.table_name = "messages"
        self.filter_attributes += [:special_attr]
      end

      assert_includes Rails.application.config.filter_parameters, "message.special_attr"
    end

    test "filter_parameters include filter_attributes for AR::Base subclasses" do
      app "development"

      assert_not_includes ActiveRecord::Base.filter_attributes, "special_attr"

      class Message < ActiveRecord::Base
        self.table_name = "messages"
      end

      Message.filter_attributes += [ :special_attr ]

      assert_includes Rails.application.config.filter_parameters, "message.special_attr"
    end

    test "filter_parameters are inherited from AR parent classes" do
      app "development"

      previous_attributes = ActiveRecord::Base.filter_attributes.dup
      previous_filter_parameters = Rails.application.config.filter_parameters.dup

      Rails.application.config.filter_parameters = ActiveRecord::Base.filter_attributes = ["generic_filtered"]
      begin
        class ApplicationRecord < ActiveRecord::Base
          self.abstract_class = true
          self.filter_attributes += [ "expires_at" ]
        end

        class CreditCard < ApplicationRecord
          self.table_name = "credit_cards"
          self.filter_attributes += [ "digits" ]
        end

        assert_equal ["generic_filtered", "credit_card.expires_at", "credit_card.digits"], Rails.application.config.filter_parameters
      ensure
        ActiveRecord::Base.filter_attributes = previous_attributes
        Rails.application.config.filter_parameters = previous_filter_parameters
      end
    end
  end
end
