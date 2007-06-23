require 'test/unit'

# Optionally load RubyGems.
begin
  require 'rubygems'
rescue LoadError
end

# Mock out what we need from AR::Base.
module ActiveRecord
  class Base
    class << self
      attr_accessor :pluralize_table_names
    end
    self.pluralize_table_names = true
  end

  module ConnectionAdapters
    class Column
      attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale

      def initialize(name, default, sql_type = nil)
        @name=name
        @default=default
        @type=@sql_type=sql_type
      end

      def human_name
        @name.humanize
      end
    end
  end
end

# And what we need from ActionView
module ActionView
  module Helpers
    module ActiveRecordHelper; end
    class InstanceTag; end
  end
end


# Must set before requiring generator libs.
tmp_dir="#{File.dirname(__FILE__)}/../fixtures/tmp"
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace(tmp_dir)
else
  RAILS_ROOT=tmp_dir
end
Dir.mkdir(RAILS_ROOT) unless File.exists?(RAILS_ROOT)

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"
require 'rails_generator'
require "#{File.dirname(__FILE__)}/generator_test_helper"

class RailsScaffoldGeneratorTest < Test::Unit::TestCase

  include GeneratorTestHelper

  def setup
    ActiveRecord::Base.pluralize_table_names = true
    Dir.mkdir("#{RAILS_ROOT}/app") unless File.exists?("#{RAILS_ROOT}/app")
    Dir.mkdir("#{RAILS_ROOT}/app/views") unless File.exists?("#{RAILS_ROOT}/app/views")
    Dir.mkdir("#{RAILS_ROOT}/app/views/layouts") unless File.exists?("#{RAILS_ROOT}/app/views/layouts")
    Dir.mkdir("#{RAILS_ROOT}/config") unless File.exists?("#{RAILS_ROOT}/config")
    Dir.mkdir("#{RAILS_ROOT}/db") unless File.exists?("#{RAILS_ROOT}/db")
    Dir.mkdir("#{RAILS_ROOT}/test") unless File.exists?("#{RAILS_ROOT}/test")
    Dir.mkdir("#{RAILS_ROOT}/test/fixtures") unless File.exists?("#{RAILS_ROOT}/test/fixtures")
    Dir.mkdir("#{RAILS_ROOT}/public") unless File.exists?("#{RAILS_ROOT}/public")
    Dir.mkdir("#{RAILS_ROOT}/public/stylesheets") unless File.exists?("#{RAILS_ROOT}/public/stylesheets")
    File.open("#{RAILS_ROOT}/config/routes.rb", 'w') do |f|
      f<<"ActionController::Routing::Routes.draw do |map|\n\nend\n"
    end
  end

  def teardown
    FileUtils.rm_rf "#{RAILS_ROOT}/app"
    FileUtils.rm_rf "#{RAILS_ROOT}/test"
    FileUtils.rm_rf "#{RAILS_ROOT}/config"
    FileUtils.rm_rf "#{RAILS_ROOT}/db"
    FileUtils.rm_rf "#{RAILS_ROOT}/public"
  end

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

    run_generator('scaffold', %w(Product))

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
    run_generator('scaffold', %w(Product --skip-migration))

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
