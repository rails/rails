require 'system_testing/base'

module Rails
  class SystemTestCase < ActionDispatch::IntegrationTest
    include SystemTesting::Base
  end
end
