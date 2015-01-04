require File.expand_path('../../../load_paths', __FILE__)

require 'active_job'
require 'support/job_buffer'

GlobalID.app = 'aj'

@adapter  = ENV['AJADAPTER'] || 'inline'

if ENV['AJ_INTEGRATION_TESTS']
  require 'support/integration/helper'
else
  require "adapters/#{@adapter}"
end

require 'active_support/testing/autorun'

ActiveSupport::TestCase.test_order = :random
