# frozen_string_literal: true

require "active_job"
require "support/job_buffer"

GlobalID.app = "aj"

@adapter = ENV["AJ_ADAPTER"] || "inline"
puts "Using #{@adapter}"

if ENV["AJ_INTEGRATION_TESTS"]
  require "support/integration/helper"
else
  ActiveJob::Base.logger = Logger.new(nil)
  require "adapters/#{@adapter}"
end

require "active_support/testing/autorun"
