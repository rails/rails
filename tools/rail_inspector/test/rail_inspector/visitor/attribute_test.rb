# frozen_string_literal: true

require "test_helper"
require "rail_inspector/visitor/attribute"

class AttributeTest < Minitest::Test
  def test_parses_attributes
    source = <<~FILE
    module Rails
      attr_accessor :logger

      class Application
        class Configuration
          attr_accessor :yjit

          attr_reader :log_level
        end
      end
    end
    FILE

    visitor = RailInspector::Visitor::Attribute.new
    Prism.parse(source).value.accept(visitor)

    assert_equal %w[logger], visitor.attribute_map["Rails"][:attr_accessor].to_a

    config_map = visitor.attribute_map["Rails::Application::Configuration"]

    assert_equal %w[yjit], config_map[:attr_accessor].to_a
    assert_equal %w[log_level], config_map[:attr_reader].to_a
  end
end
