require 'cases/helper'
require 'models/teapot'

class BasicInclusionModelTest < ActiveRecord::TestCase
  def test_basic_model
    Teapot.create!(:name => "Ronnie Kemper")
    assert_equal "Ronnie Kemper", Teapot.find(1).name
  end
end

class InclusionUnitTest < ActiveRecord::TestCase
  def setup
    @klass = Class.new { include ActiveRecord::Model }
  end

  def test_non_abstract_class
    assert !@klass.abstract_class?
  end

  def test_abstract_class
    @klass.abstract_class = true
    assert @klass.abstract_class?
  end

  def test_establish_connection
    assert @klass.respond_to?(:establish_connection)
  end

  def test_adapter_connection
    assert @klass.respond_to?("#{ActiveRecord::Base.connection_config[:adapter]}_connection")
  end

  def test_connection_handler
    assert_equal ActiveRecord::Base.connection_handler, @klass.connection_handler
  end
end
