require 'cases/helper'

class ConfigurationOnModuleTest < ActiveModel::TestCase
  def setup
    @mod = mod = Module.new do
      extend ActiveSupport::Concern
      extend ActiveModel::Configuration

      config_attribute :omg
      self.omg = "default"

      config_attribute :wtf, global: true
      self.wtf = "default"

      config_attribute :boolean

      config_attribute :lol, instance_writer: true
    end

    @klass = Class.new do
      include mod
    end

    @subklass = Class.new(@klass)
  end

  test "default" do
    assert_equal "default", @mod.omg
    assert_equal "default", @klass.omg
    assert_equal "default", @klass.new.omg
  end

  test "setting" do
    @mod.omg = "lol"
    assert_equal "lol", @mod.omg
  end

  test "setting on class including the module" do
    @klass.omg = "lol"
    assert_equal "lol", @klass.omg
    assert_equal "lol", @klass.new.omg
    assert_equal "default", @mod.omg
  end

  test "setting on subclass of class including the module" do
    @subklass.omg = "lol"
    assert_equal "lol", @subklass.omg
    assert_equal "default", @klass.omg
    assert_equal "default", @mod.omg
  end

  test "setting on instance" do
    assert !@klass.new.respond_to?(:omg=)

    @klass.lol = "lol"
    obj = @klass.new
    assert_equal "lol", obj.lol
    obj.lol = "omg"
    assert_equal "omg", obj.lol
    assert_equal "lol", @klass.lol
    assert_equal "lol", @klass.new.lol
    obj.lol = false
    assert !obj.lol?
  end

  test "global attribute" do
    assert_equal "default", @mod.wtf
    assert_equal "default", @klass.wtf

    @mod.wtf = "wtf"

    assert_equal "wtf", @mod.wtf
    assert_equal "wtf", @klass.wtf

    @klass.wtf = "lol"

    assert_equal "lol", @mod.wtf
    assert_equal "lol", @klass.wtf
  end

  test "boolean" do
    assert_equal false, @mod.boolean?
    assert_equal false, @klass.new.boolean?
    @mod.boolean = true
    assert_equal true, @mod.boolean?
    assert_equal true, @klass.new.boolean?
  end
end

class ConfigurationOnClassTest < ActiveModel::TestCase
  def setup
    @klass = Class.new do
      extend ActiveModel::Configuration

      config_attribute :omg
      self.omg = "default"

      config_attribute :wtf, global: true
      self.wtf = "default"

      config_attribute :omg2, instance_writer: true
      config_attribute :wtf2, instance_writer: true, global: true
    end

    @subklass = Class.new(@klass)
  end

  test "defaults" do
    assert_equal "default", @klass.omg
    assert_equal "default", @klass.wtf
    assert_equal "default", @subklass.omg
    assert_equal "default", @subklass.wtf
  end

  test "changing" do
    @klass.omg = "lol"
    assert_equal "lol", @klass.omg
    assert_equal "lol", @subklass.omg
  end

  test "changing in subclass" do
    @subklass.omg = "lol"
    assert_equal "lol", @subklass.omg
    assert_equal "default", @klass.omg
  end

  test "changing global" do
    @klass.wtf = "wtf"
    assert_equal "wtf", @klass.wtf
    assert_equal "wtf", @subklass.wtf

    @subklass.wtf = "lol"
    assert_equal "lol", @klass.wtf
    assert_equal "lol", @subklass.wtf
  end

  test "instance_writer" do
    obj = @klass.new

    @klass.omg2 = "omg"
    @klass.wtf2 = "wtf"

    assert_equal "omg", obj.omg2
    assert_equal "wtf", obj.wtf2

    obj.omg2 = "lol"
    obj.wtf2 = "lol"

    assert_equal "lol", obj.omg2
    assert_equal "lol", obj.wtf2
    assert_equal "omg", @klass.omg2
    assert_equal "lol", @klass.wtf2
  end
end
