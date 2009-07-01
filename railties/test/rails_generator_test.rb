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
require 'initializer'

# Mocks out the configuration
module Rails
  def self.configuration
    Rails::Configuration.new
  end
end

require 'rails_generator'

#class RailsGeneratorTest < Test::Unit::TestCase
#  BUILTINS = %w(controller integration_test mailer migration model observer plugin resource scaffold session_migration)
#  CAPITALIZED_BUILTINS = BUILTINS.map { |b| b.capitalize }

#  def setup
#    ActiveRecord::Base.pluralize_table_names = true
#    @initializer = Rails::Initializer.default
#    @initializer.config = Rails.configuration
#    @initializer.run(:set_root_path)
#  end

#  def test_sources
#    expected = [:lib, :vendor,
#                "plugins (vendor/plugins)".to_sym, # <plugin>/generators and <plugin>/rails_generators
#                :user,
#                :RubyGems, :RubyGems, # gems named <x>_generator, gems containing /rails_generator/ folder
#                :builtin]
#    expected.delete(:RubyGems) unless Object.const_defined?(:Gem)
#    assert_equal expected, Rails::Generator::Base.sources.map { |s| s.label }
#  end

#  def test_lookup_builtins
#    (BUILTINS + CAPITALIZED_BUILTINS).each do |name|
#      assert_nothing_raised do
#        spec = Rails::Generator::Base.lookup(name)
#        assert_not_nil spec
#        assert_kind_of Rails::Generator::Spec, spec

#        klass = spec.klass
#        assert klass < Rails::Generator::Base
#        assert_equal spec, klass.spec
#      end
#    end
#  end

#  def test_autolookup
#    assert_nothing_raised { ControllerGenerator }
#    assert_nothing_raised { ModelGenerator }
#  end

#  def test_lookup_missing_generator
#    assert_raise Rails::Generator::GeneratorError do
#      Rails::Generator::Base.lookup('missing').klass
#    end
#  end

#  def test_lookup_missing_class
#    spec = nil
#    assert_nothing_raised { spec = Rails::Generator::Base.lookup('missing_class') }
#    assert_not_nil spec
#    assert_kind_of Rails::Generator::Spec, spec
#    assert_raise(NameError) { spec.klass }
#  end

#  def test_generator_usage
#    (BUILTINS - ["session_migration"]).each do |name|
#      assert_raise(Rails::Generator::UsageError, "Generator '#{name}' should raise an error without arguments") {
#        Rails::Generator::Base.instance(name)
#      }
#    end
#  end

#  def test_generator_spec
#    spec = Rails::Generator::Base.lookup('working')
#    assert_equal 'working', spec.name
#    assert_match(/#{spec.path}$/, "#{RAILS_ROOT}/lib/generators/working")
#    assert_equal :lib, spec.source
#    assert_nothing_raised { assert_match(/WorkingGenerator$/, spec.klass.name) }
#  end

#end
