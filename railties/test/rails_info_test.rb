require "abstract_unit"

unless defined?(Rails) && defined?(Rails::Info)
  module Rails
    class Info; end
  end
end

require "active_support/core_ext/kernel/reporting"

class InfoTest < ActiveSupport::TestCase
  def setup
    Rails.send :remove_const, :Info
    silence_warnings { load "rails/info.rb" }
  end

  def test_property_with_block_swallows_exceptions_and_ignores_property
    assert_nothing_raised do
      Rails::Info.module_eval do
        property("Bogus") { raise }
      end
    end
    assert !property_defined?("Bogus")
  end

  def test_property_with_string
    Rails::Info.module_eval do
      property "Hello", "World"
    end
    assert_property "Hello", "World"
  end

  def test_property_with_block
    Rails::Info.module_eval do
      property("Goodbye") { "World" }
    end
    assert_property "Goodbye", "World"
  end

  def test_rails_version
    assert_property "Rails version",
      File.read(File.realpath("../../../RAILS_VERSION", __FILE__)).chomp
  end

  def test_html_includes_middleware
    Rails::Info.module_eval do
      property "Middleware", ["Rack::Lock", "Rack::Static"]
    end

    html = Rails::Info.to_html
    assert_includes html, '<tr><td class="name">Middleware</td>'
    properties.value_for("Middleware").each do |value|
      assert_includes html, "<li>#{CGI.escapeHTML(value)}</li>"
    end
  end

  private
    def properties
      Rails::Info.properties
    end

    def property_defined?(property_name)
      properties.names.include? property_name
    end

    def assert_property(property_name, value)
      raise "Property #{property_name.inspect} not defined" unless
        property_defined? property_name
      assert_equal value, properties.value_for(property_name)
    end
end
