require 'generators/generator_test_helper'

class RailsScaffoldGeneratorTest < GeneratorTestCase
  
  def test_scaffolded_names
    g = Rails::Generator::Base.instance('scaffold', %w(ProductLine))
    assert_equal "ProductLines", g.controller_name
    assert_equal "ProductLines", g.controller_class_name
    assert_equal "ProductLine", g.controller_singular_name
    assert_equal "product_lines", g.controller_plural_name
    assert_equal "product_lines", g.controller_file_name
    assert_equal "product_lines", g.controller_table_name
  end

  def test_scaffold_generates_resources

    run_generator('scaffold', %w(Product name:string))

    assert_generated_controller_for :products do |f|

      assert_has_method f, :index do |name, m|
        assert_match /@products = Product\.find\(:all\)/, m, "#{name} should query products table"
      end

      assert_has_method f, :show, :edit, :update, :destroy do |name, m|
        assert_match /@product = Product\.find\(params\[:id\]\)/, m, "#{name.to_s} should query products table"
      end

      assert_has_method f, :new do |name, m|
        assert_match /@product = Product\.new/, m, "#{name.to_s} should instantiate a product"
      end

      assert_has_method f, :create do |name, m|
        assert_match /@product = Product\.new\(params\[:product\]\)/, m, "#{name.to_s} should instantiate a product"
        assert_match /format.xml  \{ render :xml => @product.errors, :status => :unprocessable_entity \}/, m, "#{name.to_s} should set status to :unprocessable_entity code for xml"
      end

    end

    assert_generated_model_for :product
    assert_generated_functional_test_for :products
    assert_generated_unit_test_for :product
    assert_generated_fixtures_for :products
    assert_generated_helper_for :products
    assert_generated_stylesheet :scaffold
    assert_generated_views_for :products, "index.html.erb", "new.html.erb", "edit.html.erb", "show.html.erb"

    assert_generated_migration :create_products
    assert_added_route_for :products
  end

  def test_scaffold_skip_migration_skips_migration
    run_generator('scaffold', %w(Product name:string --skip-migration))

    assert_generated_model_for :product
    assert_generated_functional_test_for :products
    assert_generated_unit_test_for :product
    assert_generated_fixtures_for :products
    assert_generated_helper_for :products
    assert_generated_stylesheet :scaffold
    assert_generated_views_for :products, "index.html.erb","new.html.erb","edit.html.erb","show.html.erb"
    assert_skipped_migration :create_products
    assert_added_route_for :products
  end

  def test_scaffold_generates_resources_with_attributes
    run_generator('scaffold', %w(Product name:string supplier_id:integer created_at:timestamp))

    assert_generated_controller_for :products do |f|

      assert_has_method f, :index do |name, m|
        assert_match /@products = Product\.find\(:all\)/, m, "#{name} should query products table"
      end

      assert_has_method f, :show, :edit, :update, :destroy do |name, m|
        assert_match /@product = Product\.find\(params\[:id\]\)/, m, "#{name.to_s} should query products table"
      end

      assert_has_method f, :new do |name, m|
        assert_match /@product = Product\.new/, m, "#{name.to_s} should instantiate a product"
      end

      assert_has_method f, :create do |name, m|
        assert_match /@product = Product\.new\(params\[:product\]\)/, m, "#{name.to_s} should instantiate a product"
        assert_match /format.xml  \{ render :xml => @product.errors, :status => :unprocessable_entity \}/, m, "#{name.to_s} should set status to :unprocessable_entity code for xml"
      end

    end

    assert_generated_model_for :product
    assert_generated_functional_test_for :products
    assert_generated_unit_test_for :product
    assert_generated_fixtures_for :products
    assert_generated_helper_for :products
    assert_generated_stylesheet :scaffold
    assert_generated_views_for :products, "index.html.erb", "new.html.erb", "edit.html.erb", "show.html.erb"

    assert_generated_migration :create_products do |t|
      assert_generated_column t, :name, :string
      assert_generated_column t, :supplier_id, :integer
      assert_generated_column t, :created_at, :timestamp
    end

    assert_added_route_for :products
  end

end
