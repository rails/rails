require File.join(File.dirname(__FILE__), 'generators', 'generators_test_helper')
require 'generators/rails/model/model_generator'
require 'mocha'

class GeneratorsTest < GeneratorsTestCase
  def test_invoke_when_generator_is_not_found
    output = capture(:stdout){ Rails::Generators.invoke :unknown }
    assert_equal "Could not find generator unknown.\n", output
  end

  def test_help_when_a_generator_with_required_arguments_is_invoked_without_arguments
    output = capture(:stdout){ Rails::Generators.invoke :model, [] }
    assert_match /Description:/, output
  end

  def test_invoke_with_default_values
    Rails::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    Rails::Generators.invoke :model, ["Account"]
  end

  def test_invoke_with_config_values
    Rails::Generators::ModelGenerator.expects(:start).with(["Account"], :behavior => :skip)
    Rails::Generators.invoke :model, ["Account"], :behavior => :skip
  end

  def test_find_by_namespace_without_base_or_context
    assert_nil Rails::Generators.find_by_namespace(:model)
  end

  def test_find_by_namespace_with_base
    klass = Rails::Generators.find_by_namespace(:model, :rails)
    assert klass
    assert_equal "rails:generators:model", klass.namespace
  end

  def test_find_by_namespace_with_context
    klass = Rails::Generators.find_by_namespace(:test_unit, nil, :model)
    assert klass
    assert_equal "test_unit:generators:model", klass.namespace
  end

  def test_find_by_namespace_add_generators_to_raw_lookups
    klass = Rails::Generators.find_by_namespace("test_unit:model")
    assert klass
    assert_equal "test_unit:generators:model", klass.namespace
  end

  def test_find_by_namespace_lookup_to_the_rails_root_folder
    klass = Rails::Generators.find_by_namespace(:fixjour)
    assert klass
    assert_equal "fixjour", klass.namespace
  end

  def test_find_by_namespace_lookup_to_deep_rails_root_folders
    klass = Rails::Generators.find_by_namespace(:fixjour, :active_record)
    assert klass
    assert_equal "active_record:generators:fixjour", klass.namespace
  end

  def test_find_by_namespace_lookup_traverse_folders
    klass = Rails::Generators.find_by_namespace(:javascripts, :rails)
    assert klass
    assert_equal "rails:generators:javascripts", klass.namespace
  end

  def test_builtin_generators
    assert Rails::Generators.builtin.include? %w(rails model)
  end

  def test_rails_generators_help_with_builtin_information
    output = capture(:stdout){ Rails::Generators.help }
    assert_match /model/, output
    assert_match /scaffold_controller/, output
  end

  def test_rails_generators_with_others_information
    output = capture(:stdout){ Rails::Generators.help }.split("\n").last
    assert_equal "Others: active_record:fixjour, fixjour, rails:javascripts.", output
  end

  def test_no_color_sets_proper_shell
    Rails::Generators.no_color!
    assert_equal Thor::Shell::Basic, Thor::Base.shell
  ensure
    Thor::Base.shell = Thor::Shell::Color
  end
end
