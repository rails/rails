require "generators/generators_test_helper"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"

class NamedBaseTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ScaffoldControllerGenerator

  def test_named_generator_with_underscore
    g = generator ["line_item"]
    assert_name g, "line_item",  :name
    assert_name g, %w(),         :class_path
    assert_name g, "LineItem",   :class_name
    assert_name g, "line_item",  :file_path
    assert_name g, "line_item",  :file_name
    assert_name g, "Line item",  :human_name
    assert_name g, "line_item",  :singular_name
    assert_name g, "line_items", :plural_name
    assert_name g, "line_item",  :i18n_scope
    assert_name g, "line_items", :table_name
  end

  def test_named_generator_attributes
    g = generator ["admin/foo"]
    assert_name g, "admin/foo",  :name
    assert_name g, %w(admin),    :class_path
    assert_name g, "Admin::Foo", :class_name
    assert_name g, "admin/foo",  :file_path
    assert_name g, "foo",        :file_name
    assert_name g, "Foo",        :human_name
    assert_name g, "foo",        :singular_name
    assert_name g, "foos",       :plural_name
    assert_name g, "admin.foo",  :i18n_scope
    assert_name g, "admin_foos", :table_name
  end

  def test_named_generator_attributes_as_ruby
    g = generator ["Admin::Foo"]
    assert_name g, "Admin::Foo", :name
    assert_name g, %w(admin),    :class_path
    assert_name g, "Admin::Foo", :class_name
    assert_name g, "admin/foo",  :file_path
    assert_name g, "foo",        :file_name
    assert_name g, "foo",        :singular_name
    assert_name g, "Foo",        :human_name
    assert_name g, "foos",       :plural_name
    assert_name g, "admin.foo",  :i18n_scope
    assert_name g, "admin_foos", :table_name
  end

  def test_named_generator_attributes_without_pluralized
    original_pluralize_table_names = ActiveRecord::Base.pluralize_table_names
    ActiveRecord::Base.pluralize_table_names = false

    g = generator ["admin/foo"]
    assert_name g, "admin_foo", :table_name
  ensure
    ActiveRecord::Base.pluralize_table_names = original_pluralize_table_names
  end

  def test_scaffold_plural_names
    g = generator ["admin/foo"]
    assert_name g, "admin/foos",  :controller_name
    assert_name g, %w(admin),     :controller_class_path
    assert_name g, "Admin::Foos", :controller_class_name
    assert_name g, "admin/foos",  :controller_file_path
    assert_name g, "foos",        :controller_file_name
    assert_name g, "admin.foos",  :controller_i18n_scope
  end

  def test_scaffold_plural_names_as_ruby
    g = generator ["Admin::Foo"]
    assert_name g, "Admin::Foos", :controller_name
    assert_name g, %w(admin),     :controller_class_path
    assert_name g, "Admin::Foos", :controller_class_name
    assert_name g, "admin/foos",  :controller_file_path
    assert_name g, "foos",        :controller_file_name
    assert_name g, "admin.foos",  :controller_i18n_scope
  end

  def test_application_name
    g = generator ["Admin::Foo"]
    Rails.stub(:application, Object.new) do
      assert_name g, "object", :application_name
    end

    Rails.stub(:application, nil) do
      assert_name g, "application", :application_name
    end
  end

  def test_index_helper
    g = generator ["Post"]
    assert_name g, "posts", :index_helper
  end

  def test_index_helper_to_pluralize_once
    g = generator ["Stadium"]
    assert_name g, "stadia", :index_helper
  end

  def test_index_helper_with_uncountable
    g = generator ["Sheep"]
    assert_name g, "sheep_index", :index_helper
  end

  def test_hide_namespace
    g = generator ["Hidden"]
    g.class.stub(:namespace, "hidden") do
      assert_not_includes Rails::Generators.hidden_namespaces, "hidden"
      g.class.hide!
      assert_includes Rails::Generators.hidden_namespaces, "hidden"
    end
  end

  def test_scaffold_plural_names_with_model_name_option
    g = generator ["Admin::Foo"], model_name: "User"
    assert_name g, "user",        :singular_name
    assert_name g, "User",        :name
    assert_name g, "user",        :file_path
    assert_name g, "User",        :class_name
    assert_name g, "user",        :file_name
    assert_name g, "User",        :human_name
    assert_name g, "users",       :plural_name
    assert_name g, "user",        :i18n_scope
    assert_name g, "users",       :table_name
    assert_name g, "Admin::Foos", :controller_name
    assert_name g, %w(admin),     :controller_class_path
    assert_name g, "Admin::Foos", :controller_class_name
    assert_name g, "admin/foos",  :controller_file_path
    assert_name g, "foos",        :controller_file_name
    assert_name g, "admin.foos",  :controller_i18n_scope
  end

  private

    def assert_name(generator, value, method)
      assert_equal value, generator.send(method)
    end
end
