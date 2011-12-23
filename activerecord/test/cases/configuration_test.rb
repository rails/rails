require 'cases/helper'

class ConfigurationTest < ActiveRecord::TestCase
  def test_configuration
    @klass = Class.new do
      include ActiveRecord::Configuration
    end

    ActiveRecord::Configuration.define :omg

    ActiveRecord::Configuration.omg = "omg"

    assert_equal "omg", @klass.new.omg
    assert !@klass.new.respond_to?(:omg=)
    assert_equal "omg", @klass.omg

    @klass.omg = "wtf"

    assert_equal "wtf", @klass.omg
    assert_equal "wtf", @klass.new.omg
  ensure
    ActiveRecord::Configuration.send(:undef_method, :omg)
    ActiveRecord::Configuration::ClassMethods.send(:undef_method, :omg)
    ActiveRecord::Configuration::ClassMethods.send(:undef_method, :omg=)
  end
end
