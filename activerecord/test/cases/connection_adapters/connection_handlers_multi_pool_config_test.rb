# frozen_string_literal: true

require 'cases/helper'
require 'models/person'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersMultiPoolConfigTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def setup
        @writing_handler = ConnectionHandler.new
      end

      def teardown
        clean_up_connection_handler
      end

      unless in_memory_db?
        def test_establish_connection_with_pool_configs
          previous_env, ENV['RAILS_ENV'] = ENV['RAILS_ENV'], 'default_env'

          config = {
            'default_env' => {
              'primary' => { 'adapter' => 'sqlite3', 'database' => 'test/db/primary.sqlite3' }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          @writing_handler.establish_connection(:primary)
          @writing_handler.establish_connection(:primary, shard: :pool_config_two)

          default_pool = @writing_handler.retrieve_connection_pool('primary', shard: :default)
          other_pool = @writing_handler.retrieve_connection_pool('primary', shard: :pool_config_two)

          assert_not_nil default_pool
          assert_not_equal default_pool, other_pool

          # :default if passed with no key
          assert_equal default_pool, @writing_handler.retrieve_connection_pool('primary')
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV['RAILS_ENV'] = previous_env
        end

        def test_remove_connection
          previous_env, ENV['RAILS_ENV'] = ENV['RAILS_ENV'], 'default_env'

          config = {
            'default_env' => {
              'primary' => { 'adapter' => 'sqlite3', 'database' => 'test/db/primary.sqlite3' }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          @writing_handler.establish_connection(:primary)
          @writing_handler.establish_connection(:primary, shard: :pool_config_two)

          # remove default
          @writing_handler.remove_connection_pool('primary')

          assert_nil @writing_handler.retrieve_connection_pool('primary')
          assert_not_nil @writing_handler.retrieve_connection_pool('primary', shard: :pool_config_two)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV['RAILS_ENV'] = previous_env
        end

        def test_connected?
          previous_env, ENV['RAILS_ENV'] = ENV['RAILS_ENV'], 'default_env'

          config = {
            'default_env' => {
              'primary' => { 'adapter' => 'sqlite3', 'database' => 'test/db/primary.sqlite3' }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          @writing_handler.establish_connection(:primary)
          @writing_handler.establish_connection(:primary, shard: :pool_config_two)

          # connect to default
          @writing_handler.connection_pool_list.first.checkout

          assert @writing_handler.connected?('primary')
          assert @writing_handler.connected?('primary', shard: :default)
          assert_not @writing_handler.connected?('primary', shard: :pool_config_two)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV['RAILS_ENV'] = previous_env
        end
      end
    end
  end
end
