# frozen_string_literal: true

require "cases/helper"
require "tempfile"
require "fileutils"
require "models/zine"

class TestFixturesTest < ActiveRecord::TestCase
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

  unless in_memory_db?
    def test_doesnt_rely_on_active_support_test_case_specific_methods
      tmp_dir = Dir.mktmpdir
      File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
      going_out:
        title: Hello
      YML

      klass = Class.new(Minitest::Test) do
        include ActiveRecord::TestFixtures

        self.fixture_path = tmp_dir
        self.use_transactional_tests = true

        fixtures :all

        def test_run_successfully
          assert_equal("Hello", Zine.first.title)
          assert_equal("Hello", zines(:going_out).title)
        end
      end

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
  end
end
