require "cases/helper"

class TestFixturesTest < ActiveRecord::TestCase
  setup do
    @klass = Class.new
    @klass.send(:include, ActiveRecord::TestFixtures)
  end

  def test_deprecated_use_transactional_fixtures=
    assert_deprecated "use use_transactional_tests= instead" do
      @klass.use_transactional_fixtures = true
    end
  end

  def test_use_transactional_tests_prefers_use_transactional_fixtures
    ActiveSupport::Deprecation.silence do
      @klass.use_transactional_fixtures = false
    end

    assert_equal false, @klass.use_transactional_tests
  end

  def test_use_transactional_tests_defaults_to_true
    ActiveSupport::Deprecation.silence do
      @klass.use_transactional_fixtures = nil
    end

    assert_equal true, @klass.use_transactional_tests
  end

  def test_use_transactional_tests_can_be_overridden
    @klass.use_transactional_tests = "foobar"

    assert_equal "foobar", @klass.use_transactional_tests
  end
end
