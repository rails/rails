require 'test_helper'
require_relative './common'

require 'active_record'

class PostgresqlAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def setup
    database_config = { 'adapter' => 'postgresql', 'database' => 'activerecord_unittest' }
    ar_tests = File.expand_path('../../../activerecord/test', __dir__)
    if Dir.exist?(ar_tests)
      require File.join(ar_tests, 'config')
      require File.join(ar_tests, 'support/config')
      local_config = ARTest.config['arunit']
      database_config.update local_config if local_config
    end
    ActiveRecord::Base.establish_connection database_config

    super
  end

  def teardown
    super

    ActiveRecord::Base.clear_all_connections!
  end

  def cable_config
    { adapter: 'postgresql' }
  end
end
