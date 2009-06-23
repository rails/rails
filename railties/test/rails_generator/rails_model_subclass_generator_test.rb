require 'generators/generator_test_helper'

class RailsModelSubclassGeneratorTest < GeneratorTestCase

  def test_model_subclass_generates_resources
    run_generator('model_subclass', %w(Car Product))

    assert_generated_model_for :car, "Product"
    assert_generated_unit_test_for :car
  end

  def test_model_subclass_must_have_a_parent_class_name
    assert_raise(Rails::Generator::UsageError) { run_generator('model_subclass', %w(Car)) }
  end
end