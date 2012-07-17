require 'generators/generators_test_helper'
require 'rails/generators/rails/model/model_generator'
require 'rails/generators/test_unit/model/model_generator'

class GeneratorsTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    @path = File.expand_path("lib", Rails.root)
    $LOAD_PATH.unshift(@path)
  end

  def teardown
    $LOAD_PATH.delete(@path)
  end

  def test_simple_invoke
    assert File.exists?(File.join(@path, 'generators', 'model_generator.rb'))
    TestUnit::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    Rails::Generators.invoke("test_unit:model", ["Account"])
  end

  def test_invoke_when_generator_is_not_found
    output = capture(:stdout){ Rails::Generators.invoke :unknown }
    assert_equal "Could not find generator unknown.\n", output
  end

  def test_help_when_a_generator_with_required_arguments_is_invoked_without_arguments
    output = capture(:stdout){ Rails::Generators.invoke :model, [] }
    assert_match(/Description:/, output)
  end

  def test_should_give_higher_preference_to_rails_generators
    assert File.exists?(File.join(@path, 'generators', 'model_generator.rb'))
    Rails::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    warnings = capture(:stderr){ Rails::Generators.invoke :model, ["Account"] }
    assert warnings.empty?
  end

  def test_invoke_with_default_values
    Rails::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    Rails::Generators.invoke :model, ["Account"]
  end

  def test_invoke_with_config_values
    Rails::Generators::ModelGenerator.expects(:start).with(["Account"], :behavior => :skip)
    Rails::Generators.invoke :model, ["Account"], :behavior => :skip
  end

  def test_find_by_namespace
    klass = Rails::Generators.find_by_namespace("rails:model")
    assert klass
    assert_equal "rails:model", klass.namespace
  end

  def test_find_by_namespace_with_base
    klass = Rails::Generators.find_by_namespace(:model, :rails)
    assert klass
    assert_equal "rails:model", klass.namespace
  end

  def test_find_by_namespace_with_context
    klass = Rails::Generators.find_by_namespace(:test_unit, nil, :model)
    assert klass
    assert_equal "test_unit:model", klass.namespace
  end

  def test_find_by_namespace_with_generator_on_root
    klass = Rails::Generators.find_by_namespace(:fixjour)
    assert klass
    assert_equal "fixjour", klass.namespace
  end

  def test_find_by_namespace_in_subfolder
    klass = Rails::Generators.find_by_namespace(:fixjour, :active_record)
    assert klass
    assert_equal "active_record:fixjour", klass.namespace
  end

  def test_find_by_namespace_with_duplicated_name
    klass = Rails::Generators.find_by_namespace(:foobar)
    assert klass
    assert_equal "foobar:foobar", klass.namespace
  end

  def test_find_by_namespace_without_base_or_context_looks_into_rails_namespace
    assert Rails::Generators.find_by_namespace(:model)
  end

  def test_invoke_with_nested_namespaces
    model_generator = mock('ModelGenerator') do
      expects(:start).with(["Account"], {})
    end
    Rails::Generators.expects(:find_by_namespace).with('namespace', 'my:awesome').returns(model_generator)
    Rails::Generators.invoke 'my:awesome:namespace', ["Account"]
  end

  def test_rails_generators_help_with_builtin_information
    output = capture(:stdout){ Rails::Generators.help }
    assert_match(/Rails:/, output)
    assert_match(/^  model$/, output)
    assert_match(/^  scaffold_controller$/, output)
    assert_no_match(/^  app$/, output)
  end

  def test_rails_generators_help_does_not_include_app_nor_plugin_new
    output = capture(:stdout){ Rails::Generators.help }
    assert_no_match(/app/, output)
    assert_no_match(/plugin_new/, output)
  end

  def test_rails_generators_with_others_information
    output = capture(:stdout){ Rails::Generators.help }
    assert_match(/Fixjour:/, output)
    assert_match(/^  fixjour$/, output)
  end

  def test_rails_generators_does_not_show_active_record_hooks
    output = capture(:stdout){ Rails::Generators.help }
    assert_match(/ActiveRecord:/, output)
    assert_match(/^  active_record:fixjour$/, output)
  end

  def test_default_banner_should_show_generator_namespace
    klass = Rails::Generators.find_by_namespace(:foobar)
    assert_match(/^rails generate foobar:foobar/, klass.banner)
  end

  def test_default_banner_should_not_show_rails_generator_namespace
    klass = Rails::Generators.find_by_namespace(:model)
    assert_match(/^rails generate model/, klass.banner)
  end

  def test_no_color_sets_proper_shell
    Rails::Generators.no_color!
    assert_equal Thor::Shell::Basic, Thor::Base.shell
  ensure
    Thor::Base.shell = Thor::Shell::Color
  end

  def test_fallbacks_for_generators_on_find_by_namespace
    Rails::Generators.fallbacks[:remarkable] = :test_unit
    klass = Rails::Generators.find_by_namespace(:plugin, :remarkable)
    assert klass
    assert_equal "test_unit:plugin", klass.namespace
  end

  def test_fallbacks_for_generators_on_find_by_namespace_with_context
    Rails::Generators.fallbacks[:remarkable] = :test_unit
    klass = Rails::Generators.find_by_namespace(:remarkable, :rails, :plugin)
    assert klass
    assert_equal "test_unit:plugin", klass.namespace
  end

  def test_fallbacks_for_generators_on_invoke
    Rails::Generators.fallbacks[:shoulda] = :test_unit
    TestUnit::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    Rails::Generators.invoke "shoulda:model", ["Account"]
  end

  def test_nested_fallbacks_for_generators
    Rails::Generators.fallbacks[:super_shoulda] = :shoulda
    TestUnit::Generators::ModelGenerator.expects(:start).with(["Account"], {})
    Rails::Generators.invoke "super_shoulda:model", ["Account"]
  end

  def test_developer_options_are_overwriten_by_user_options
    Rails::Generators.options[:with_options] = { :generate => false }

    self.class.class_eval(<<-end_eval, __FILE__, __LINE__ + 1)
      class WithOptionsGenerator < Rails::Generators::Base
        class_option :generate, :default => true
      end
    end_eval

    assert_equal false, WithOptionsGenerator.class_options[:generate].default
  ensure
    Rails::Generators.subclasses.delete(WithOptionsGenerator)
  end

  def test_rails_root_templates
    template = File.join(Rails.root, "lib", "templates", "active_record", "model", "model.rb")

    # Create template
    mkdir_p(File.dirname(template))
    File.open(template, 'w'){ |f| f.write "empty" }

    capture(:stdout) do
      Rails::Generators.invoke :model, ["user"], :destination_root => destination_root
    end

    assert_file "app/models/user.rb" do |content|
      assert_equal "empty", content
    end
  ensure
    rm_rf File.dirname(template)
  end

  def test_source_paths_for_not_namespaced_generators
    mspec = Rails::Generators.find_by_namespace :fixjour
    assert mspec.source_paths.include?(File.join(Rails.root, "lib", "templates", "fixjour"))
  end

  def test_usage_with_embedded_ruby
    require File.expand_path("fixtures/lib/generators/usage_template/usage_template_generator", File.dirname(__FILE__))
    output = capture(:stdout) { Rails::Generators.invoke :usage_template, ['--help'] }
    assert_match(/:: 2 ::/, output)
  end

  def test_hide_namespace
    assert !Rails::Generators.hidden_namespaces.include?("special:namespace")
    Rails::Generators.hide_namespace("special:namespace")
    assert Rails::Generators.hidden_namespaces.include?("special:namespace")
  end
end
