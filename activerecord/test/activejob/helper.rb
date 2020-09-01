# frozen_string_literal: true

require "cases/helper"

require "global_id"
GlobalID.app = "ActiveRecordExampleApp"
ActiveRecord::Base.include GlobalID::Identification

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

require_relative "../../../tools/test_common"

ActiveRecord::Base.destroy_later_job = ActiveRecord::DestroyJob
