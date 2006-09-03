require 'test/unit'

# Optionally load RubyGems.
begin
  require 'rubygems'
rescue LoadError
end

# Mock out what we need from AR::Base.
module ActiveRecord
  class Base
    class << self
      attr_accessor :pluralize_table_names
    end
    self.pluralize_table_names = true
  end
end

# And what we need from ActionView
module ActionView
  module Helpers
    module ActiveRecordHelper; end
    class InstanceTag; end
  end
end


# Must set before requiring generator libs.
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace "#{File.dirname(__FILE__)}/fixtures"
else
  RAILS_ROOT = "#{File.dirname(__FILE__)}/fixtures"
end

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'rails_generator'


class RailsGeneratorTest < Test::Unit::TestCase
  BUILTINS = %w(controller mailer model scaffold)
  CAPITALIZED_BUILTINS = BUILTINS.map { |b| b.capitalize }

  def test_sources
    expected = [:lib, :vendor, :plugins, :user, :RubyGems, :builtin]
    expected.delete(:gem) unless Object.const_defined?(:Gem)
    assert_equal expected, Rails::Generator::Base.sources.map { |s| s.label }
  end

  def test_lookup_builtins
    (BUILTINS + CAPITALIZED_BUILTINS).each do |name|
      assert_nothing_raised do
        spec = Rails::Generator::Base.lookup(name)
        assert_not_nil spec
        assert_kind_of Rails::Generator::Spec, spec

        klass = spec.klass
        assert klass < Rails::Generator::Base
        assert_equal spec, klass.spec
      end
    end
  end

  def test_autolookup
    assert_nothing_raised { ControllerGenerator }
    assert_nothing_raised { ModelGenerator }
  end

  def test_lookup_missing_generator
    assert_raise(MissingSourceFile) {
      Rails::Generator::Base.lookup('missing_generator').klass
    }
  end

  def test_lookup_missing_class
    spec = nil
    assert_nothing_raised { spec = Rails::Generator::Base.lookup('missing_class') }
    assert_not_nil spec
    assert_kind_of Rails::Generator::Spec, spec
    assert_raise(NameError) { spec.klass }
  end

  def test_generator_usage
    BUILTINS.each do |name|
      assert_raise(Rails::Generator::UsageError) {
        Rails::Generator::Base.instance(name)
      }
    end
  end

  def test_generator_spec
    spec = Rails::Generator::Base.lookup('working')
    assert_equal 'working', spec.name
    assert_equal "#{RAILS_ROOT}/lib/generators/working", spec.path
    assert_equal :lib, spec.source
    assert_nothing_raised { assert_match(/WorkingGenerator$/, spec.klass.name) }
  end

  def test_named_generator_attributes
    ActiveRecord::Base.pluralize_table_names = true
    g = Rails::Generator::Base.instance('working', %w(admin/foo bar baz))
    assert_equal 'admin/foo', g.name
    assert_equal %w(admin), g.class_path
    assert_equal 'Admin', g.class_nesting
    assert_equal 'Admin::Foo', g.class_name
    assert_equal 'foo', g.singular_name
    assert_equal 'foos', g.plural_name
    assert_equal g.singular_name, g.file_name
    assert_equal g.plural_name, g.table_name
    assert_equal %w(bar baz), g.args
  end

  def test_named_generator_attributes_without_pluralized
    ActiveRecord::Base.pluralize_table_names = false
    g = Rails::Generator::Base.instance('working', %w(admin/foo bar baz))
    assert_equal g.singular_name, g.table_name
  end
  
  def test_scaffold_controller_name
    # Default behaviour is use the model name
    g = Rails::Generator::Base.instance('scaffold', %w(Product))
    assert_equal "Product", g.controller_name
    
    # When we specify a controller name make sure it sticks!!
    g = Rails::Generator::Base.instance('scaffold', %w(Product Admin))
    assert_equal "Admin", g.controller_name
  end  
end
