# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"
require "rails/generators/rails/model/model_generator"

# Mock out two ORMs
module ORMWithGenerators
  module Generators
    class ActiveModel
      def initialize(name)
      end
    end
  end
end

module ORMWithoutGenerators
  # No generators
end

class ScaffoldOrmTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ScaffoldControllerGenerator

  def test_orm_class_returns_custom_generator_if_supported_custom_orm_set
    g = generator ["Foo"], orm: "ORMWithGenerators"
    assert_equal ORMWithGenerators::Generators::ActiveModel, g.send(:orm_class)
  end

  def test_orm_class_returns_rails_generator_if_unsupported_custom_orm_set
    g = generator ["Foo"], orm: "ORMWithoutGenerators"
    assert_equal Rails::Generators::ActiveModel, g.send(:orm_class)
  end

  def test_orm_instance_returns_orm_class_instance_with_name
    g = generator ["Foo"]
    orm_instance = g.send(:orm_instance)
    assert g.send(:orm_class) === orm_instance
    assert_equal "foo", orm_instance.name
  end
end

module TestOrmWithDescription
  module Generators
    class ModelGenerator < Rails::Generators::ModelGenerator
      def self.usage_path
        true
      end

      def self.desc
        "My description"
      end
    end
  end
end

class ModelOrmTest < ActiveSupport::TestCase
  def test_active_record_description_is_used_by_default
    assert_match(/Description:.*/, Rails::Generators::ModelGenerator.desc)
  end

  def test_orm_description_is_used_when_configured
    with_configured(:orm, :test_orm_with_description) do
      assert_equal("My description", Rails::Generators::ModelGenerator.desc)
    end
  end

  private
    def with_configured(hook, value)
      previous_default = Rails::Generators::ModelGenerator.class_options[hook].default
      Rails::Generators::ModelGenerator.class_options[hook].instance_variable_set(:@default, value)
      yield
    ensure
      Rails::Generators::ModelGenerator.class_options[hook].instance_variable_set(:@default, previous_default)
    end
end
