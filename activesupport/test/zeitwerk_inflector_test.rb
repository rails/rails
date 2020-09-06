# frozen_string_literal: true

require_relative 'abstract_unit'
require 'active_support/dependencies/zeitwerk_integration'

class ZeitwerkInflectorTest < ActiveSupport::TestCase
  INFLECTOR = ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector

  def reset_overrides
    INFLECTOR.instance_variable_get(:@overrides).clear
  end

  def camelize(basename)
    INFLECTOR.camelize(basename, nil)
  end

  setup do
    reset_overrides
    @original_inflections = ActiveSupport::Inflector::Inflections.instance_variable_get(:@__instance__)[:en]
    ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: @original_inflections.dup)
  end

  teardown do
    reset_overrides
    ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: @original_inflections)
  end

  test 'it camelizes regular basenames with String#camelize' do
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym('SSL')
    end

    assert_equal 'User', camelize('user')
    assert_equal 'UsersController', camelize('users_controller')
    assert_equal 'Point3d', camelize('point_3d')
    assert_equal 'SSLError', camelize('ssl_error')
  end

  test 'overrides take precedence' do
    # Precondition, ensure we are testing something.
    assert_equal 'MysqlAdapter', camelize('mysql_adapter')

    INFLECTOR.inflect('mysql_adapter' => 'MySQLAdapter')
    assert_equal 'MySQLAdapter', camelize('mysql_adapter')

    # The fallback is still in place.
    assert_equal 'UsersController', camelize('users_controller')
  end
end
