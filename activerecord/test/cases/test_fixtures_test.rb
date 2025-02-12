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

    def test_transactional_tests_per_db_explicitly_disabled
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_paths = [tmp_dir]
        self.use_transactional_tests = true
        self.skip_transactional_tests_for_database :primary

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
          # Change the data in the primary connection
          Zine.first.update!(title: "Goodbye")
        end
      end

      test_result = klass.new("test_run_successfully").run
      assert_predicate(test_result, :passed?)
      # Ensure that the primary connection was NOT rolled back
      assert_equal("Goodbye", Zine.first.title)
    ensure
      FileUtils.rm_r(tmp_dir)
    end

    def test_transactional_tests_per_db_explicitly_enabled
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_paths = [tmp_dir]
        self.use_transactional_tests = false
        self.use_transactional_tests_for_database :primary

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
          # Change the data in the primary connection
          Zine.first.update!(title: "Goodbye")
        end
      end

      test_result = klass.new("test_run_successfully").run
      assert_predicate(test_result, :passed?)
      # Ensure that the primary connection WAS rolled back
      assert_equal("Hello", Zine.first.title)
    ensure
      FileUtils.rm_r(tmp_dir)
    end

    def test_transactional_tests_per_db_default_enabled
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_paths = [tmp_dir]
        self.use_transactional_tests = true
        self.skip_transactional_tests_for_database :unrelated

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
          # Change the data in the primary connection
          Zine.first.update!(title: "Goodbye")
        end
      end

      test_result = klass.new("test_run_successfully").run
      assert_predicate(test_result, :passed?)
      # Ensure that the primary connection WAS rolled back
      assert_equal("Hello", Zine.first.title)
    ensure
      FileUtils.rm_r(tmp_dir)
    end

    def test_transactional_tests_per_db_default_disabled
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_paths = [tmp_dir]
        self.use_transactional_tests = false
        self.use_transactional_tests_for_database :unrelated

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
          # Change the data in the primary connection
          Zine.first.update!(title: "Goodbye")
        end
      end

      test_result = klass.new("test_run_successfully").run
      assert_predicate(test_result, :passed?)
      # Ensure that the primary connection was NOT rolled back
      assert_equal("Goodbye", Zine.first.title)
    ensure
      FileUtils.rm_r(tmp_dir)
    end
  end
end
