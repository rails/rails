# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/model/model_generator"
require "rails/generators/test_unit/model/model_generator"

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
    assert File.exist?(File.join(@path, "generators", "model_generator.rb"))
    assert_called_with(TestUnit::Generators::ModelGenerator, :start, [["Account"], {}]) do
      Rails::Generators.invoke("test_unit:model", ["Account"])
    end
  end

  def test_invoke_when_generator_is_not_found
    name = :unknown
    output = capture(:stdout) { Rails::Generators.invoke name }
    assert_match "Could not find generator '#{name}'", output
    assert_match "`bin/rails generate --help`", output
    assert_no_match "Maybe you meant", output
  end

  def test_generator_suggestions
    name = :migrationz
    output = capture(:stdout) { Rails::Generators.invoke name }
    assert_match 'Maybe you meant "migration"?', output
  end

  def test_generator_suggestions_except_en_locale
    orig_available_locales = I18n.available_locales
    orig_default_locale = I18n.default_locale
    I18n.available_locales = :ja
    I18n.default_locale = :ja
    name = :tas
    output = capture(:stdout) { Rails::Generators.invoke name }
    assert_match 'Maybe you meant "task"?', output
  ensure
    I18n.available_locales = orig_available_locales
    I18n.default_locale = orig_default_locale
  end

  def test_help_when_a_generator_with_required_arguments_is_invoked_without_arguments
    output = capture(:stdout) { Rails::Generators.invoke :model, [] }
    assert_match(/Description:/, output)
  end

  def test_should_give_higher_preference_to_rails_generators
    assert File.exist?(File.join(@path, "generators", "model_generator.rb"))
    assert_called_with(Rails::Generators::ModelGenerator, :start, [["Account"], {}]) do
      warnings = capture(:stderr) { Rails::Generators.invoke :model, ["Account"] }
      assert_empty warnings
    end
  end

  def test_invoke_with_default_values
    assert_called_with(Rails::Generators::ModelGenerator, :start, [["Account"], {}]) do
      Rails::Generators.invoke :model, ["Account"]
    end
  end

  def test_invoke_with_config_values
    assert_called_with(Rails::Generators::ModelGenerator, :start, [["Account"], behavior: :skip]) do
      Rails::Generators.invoke :model, ["Account"], behavior: :skip
    end
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
    model_generator = Minitest::Mock.new
    model_generator.expect(:start, nil, [["Account"], {}])
    assert_called_with(Rails::Generators, :find_by_namespace, ["namespace", "my:awesome"], returns: model_generator) do
      Rails::Generators.invoke "my:awesome:namespace", ["Account"]
    end
    model_generator.verify
  end

  def test_rails_generators_help_with_builtin_information
    output = capture(:stdout) { Rails::Generators.help }
    assert_match(/Rails:/, output)
    assert_match(/^  model$/, output)
    assert_match(/^  scaffold_controller$/, output)
    assert_no_match(/^  app$/, output)
  end

  def test_rails_generators_help_does_not_include_app_nor_plugin_new
    output = capture(:stdout) { Rails::Generators.help }
    assert_no_match(/app\W/, output)
    assert_no_match(/[^:]plugin/, output)
  end

  def test_rails_generators_with_others_information
    output = capture(:stdout) { Rails::Generators.help }
    assert_match(/Fixjour:/, output)
    assert_match(/^  fixjour$/, output)
  end

  def test_rails_generators_does_not_show_active_record_hooks
    output = capture(:stdout) { Rails::Generators.help }
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
  ensure
    Rails::Generators.fallbacks.delete(:remarkable)
  end

  def test_fallbacks_for_generators_on_find_by_namespace_with_context
    Rails::Generators.fallbacks[:remarkable] = :test_unit
    klass = Rails::Generators.find_by_namespace(:remarkable, :rails, :plugin)
    assert klass
    assert_equal "test_unit:plugin", klass.namespace
  ensure
    Rails::Generators.fallbacks.delete(:remarkable)
  end

  def test_fallbacks_for_generators_on_invoke
    Rails::Generators.fallbacks[:shoulda] = :test_unit
    assert_called_with(TestUnit::Generators::ModelGenerator, :start, [["Account"], {}]) do
      Rails::Generators.invoke "shoulda:model", ["Account"]
    end
  ensure
    Rails::Generators.fallbacks.delete(:shoulda)
  end

  def test_nested_fallbacks_for_generators
    Rails::Generators.fallbacks[:shoulda] = :test_unit
    Rails::Generators.fallbacks[:super_shoulda] = :shoulda
    assert_called_with(TestUnit::Generators::ModelGenerator, :start, [["Account"], {}]) do
      Rails::Generators.invoke "super_shoulda:model", ["Account"]
    end
  ensure
    Rails::Generators.fallbacks.delete(:shoulda)
    Rails::Generators.fallbacks.delete(:super_shoulda)
  end

  def test_developer_options_are_overwritten_by_user_options
    Rails::Generators.options[:with_options] = { generate: false }

    self.class.class_eval(<<-end_eval, __FILE__, __LINE__ + 1)
      class WithOptionsGenerator < Rails::Generators::Base
        class_option :generate, default: true, type: :boolean
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
    File.open(template, "w") { |f| f.write "empty" }

    capture(:stdout) do
      Rails::Generators.invoke :model, ["user"], destination_root: destination_root
    end

    assert_file "app/models/user.rb" do |content|
      assert_equal "empty", content
    end
  ensure
    rm_rf File.dirname(template)
  end

  def test_source_paths_for_not_namespaced_generators
    mspec = Rails::Generators.find_by_namespace :fixjour
    assert_includes mspec.source_paths, File.join(Rails.root, "lib", "templates", "fixjour")
  end

  def test_usage_with_embedded_ruby
    require_relative "fixtures/lib/generators/usage_template/usage_template_generator"
    output = capture(:stdout) { Rails::Generators.invoke :usage_template, ["--help"] }
    assert_match(/:: 2 ::/, output)
  end

  def test_hide_namespace
    assert_not_includes Rails::Generators.hidden_namespaces, "special:namespace"
    Rails::Generators.hide_namespace("special:namespace")
    assert_includes Rails::Generators.hidden_namespaces, "special:namespace"
  end
end
