# frozen_string_literal: true

require "abstract_unit"

class InfoTest < ActiveSupport::TestCase
  def test_property_with_block_swallows_exceptions_and_ignores_property
    assert_nothing_raised do
      Rails::Info.module_eval do
        property("Bogus") { raise }
      end
    end
    assert_not property_defined?("Bogus")
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
      File.read(File.realpath("../../RAILS_VERSION", __dir__)).chomp
  end

  def test_to_s_includes_configuration
    Rails::Info.module_eval do
      property "Configuration", { "foo" => "bar" }
    end

    output = Rails::Info.to_s
    properties.value_for("Configuration").each do |key, value|
      assert_includes output, "Configuration      #{key}   #{value}"
    end
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

  def test_html_includes_configuration
    Rails::Info.module_eval do
      property "Configuration", { "foo" => "bar" }
    end

    html = Rails::Info.to_html
    properties.value_for("Configuration").each do |config, config_value|
      assert_includes html, "<tr><td>#{config}</td><td>#{config_value}</td></tr>"
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
