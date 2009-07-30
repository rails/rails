require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/scaffold_controller/scaffold_controller_generator'

# Mock out what we need from AR::Base.
module ActiveRecord
  class Base
    class << self
      attr_accessor :pluralize_table_names
    end
    self.pluralize_table_names = true
  end
end

class NamedBaseTest < GeneratorsTestCase

  def test_named_generator_attributes
    g = Rails::Generators::ScaffoldControllerGenerator.new ["admin/foo"]
    assert_equal 'admin/foo', g.name
    assert_equal %w(admin), g.class_path
    assert_equal 1, g.class_nesting_depth
    assert_equal 'Admin::Foo', g.class_name
    assert_equal 'foo', g.singular_name
    assert_equal 'foos', g.plural_name
    assert_equal g.singular_name, g.file_name
    assert_equal "admin_#{g.plural_name}", g.table_name
  end

  def test_named_generator_attributes_without_pluralized
    ActiveRecord::Base.pluralize_table_names = false
    g = Rails::Generators::ScaffoldControllerGenerator.new ["admin/foo"]
    assert_equal "admin_#{g.singular_name}", g.table_name
  end

  def test_scaffold_plural_names
    g = Rails::Generators::ScaffoldControllerGenerator.new ["ProductLine"]
    assert_equal "ProductLines", g.controller_name
    assert_equal "ProductLines", g.controller_class_name
    assert_equal "product_lines", g.controller_file_name
  end

end
