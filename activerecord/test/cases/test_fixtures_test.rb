# frozen_string_literal: true

require "cases/helper"
require "tempfile"
require "fileutils"
require "models/zine"

class TestFixturesTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    @klass = Class.new
    @klass.include(ActiveRecord::TestFixtures)
  end

  def test_use_transactional_tests_defaults_to_true
    assert_equal true, @klass.use_transactional_tests
  end

  def test_use_transactional_tests_can_be_overridden
    @klass.use_transactional_tests = "foobar"

    assert_equal "foobar", @klass.use_transactional_tests
  end

  def test_inclusion_runs_active_record_fixtures_load_hook
    ActiveSupport.on_load(:active_record_fixtures) do
      self.fixture_paths << "test/fixtures"
    end
    klass = Class.new

    klass.include(ActiveRecord::TestFixtures)

    assert_includes klass.fixture_paths, "test/fixtures"
  end

  unless in_memory_db?
    def test_doesnt_rely_on_active_support_test_case_specific_methods
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_paths = [tmp_dir]
        self.use_transactional_tests = true

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
        end
      end

      ActiveSupport::Notifications.unsubscribe(@connection_subscriber)
      @connection_subscriber = nil

      old_handler = ActiveRecord::Base.connection_handler
      ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      ActiveRecord::Base.establish_connection(:arunit)

      test_result = klass.new("test_run_successfully").run
      assert_predicate(test_result, :passed?)
    ensure
      ActiveRecord::Base.connection_handler = old_handler
      clean_up_connection_handler
      FileUtils.rm_r(tmp_dir)
    end


    def test_teardown_shared_connection_pool_disconnects_pool_configs_for_removed_roles
      handler = ActiveRecord::Base.connection_handler
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      pool_manager = handler.instance_variable_get(:@connection_name_to_pool_manager)["ActiveRecord::Base"]
      writing_pool_config = pool_manager.get_pool_config(:writing, :default)
      reading_pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :reading, :default)
      pool_manager.set_pool_config(:reading, :default, reading_pool_config)

      reading_pool = reading_pool_config.pool
      connection = reading_pool.checkout
      connection.execute("SELECT 1")
      reading_pool.checkin(connection)

      setup_shared_connection_pool
      assert_same writing_pool_config, pool_manager.get_pool_config(:reading, :default)

      clean_up_connection_handler
      teardown_shared_connection_pool

      assert_predicate writing_pool_config.pool, :automatic_reconnect
      assert_not_predicate reading_pool, :connected?
    ensure
      teardown_shared_connection_pool if defined?(@saved_pool_configs) && @saved_pool_configs.any?
      clean_up_connection_handler
    end
  end
end
