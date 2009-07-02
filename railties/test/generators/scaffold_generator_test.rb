require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/active_record'
require 'generators/rails/scaffold/scaffold_generator'
require 'generators/rails/stylesheets/stylesheets_generator'

# Model
require 'generators/active_record/model/model_generator'
require 'generators/rails/model/model_generator'
require 'generators/test_unit/model/model_generator'

# Controller
require 'generators/erb/scaffold/scaffold_generator'
require 'generators/rails/scaffold_controller/scaffold_controller_generator'
require 'generators/rails/helper/helper_generator'
require 'generators/test_unit/scaffold/scaffold_generator'
require 'generators/test_unit/helper/helper_generator'

class ScaffoldGeneratorTest < GeneratorsTestCase

  def setup
    super
    routes = Rails::Generators::ResourceGenerator.source_root
    routes = File.join(routes, "..", "..", "app", "templates", "config", "routes.rb")
    destination = File.join(destination_root, "config")

    FileUtils.mkdir_p(destination)
    FileUtils.cp File.expand_path(routes), destination
  end

  def test_scaffold_on_invoke
    run_generator

    # Model
    assert_file "app/models/product_line.rb", /class ProductLine < ActiveRecord::Base/
    assert_file "test/unit/product_line_test.rb", /class ProductLineTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/product_lines.yml"
    assert_migration "db/migrate/create_product_lines.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match /map\.resources :product_lines$/, route
    end

    # Controller
    assert_file "app/controllers/product_lines_controller.rb" do |content|
      assert_match /class ProductLinesController < ApplicationController/, content

      assert_instance_method content, :index do |m|
        assert_match /@product_lines = ProductLine\.all/, m
      end

      assert_instance_method content, :show do |m|
        assert_match /@product_line = ProductLine\.find\(params\[:id\]\)/, m
      end

      assert_instance_method content, :new do |m|
        assert_match /@product_line = ProductLine\.new/, m
      end

      assert_instance_method content, :edit do |m|
        assert_match /@product_line = ProductLine\.find\(params\[:id\]\)/, m
      end

      assert_instance_method content, :create do |m|
        assert_match /@product_line = ProductLine\.new\(params\[:product_line\]\)/, m
        assert_match /@product_line\.save/, m
        assert_match /@product_line\.errors/, m
      end

      assert_instance_method content, :update do |m|
        assert_match /@product_line = ProductLine\.find\(params\[:id\]\)/, m
        assert_match /@product_line\.update_attributes\(params\[:product_line\]\)/, m
        assert_match /@product_line\.errors/, m
      end

      assert_instance_method content, :destroy do |m|
        assert_match /@product_line = ProductLine\.find\(params\[:id\]\)/, m
        assert_match /@product_line\.destroy/, m
      end
    end

    assert_file "test/functional/product_lines_controller_test.rb",
                /class ProductLinesControllerTest < ActionController::TestCase/

    # Views
    %w(
      index
      edit
      new
      show
    ).each { |view| assert_file "app/views/product_lines/#{view}.html.erb" }
    assert_file "app/views/layouts/product_lines.html.erb"

    # Helpers
    assert_file "app/helpers/product_lines_helper.rb"
    assert_file "test/unit/helpers/product_lines_helper_test.rb"

    # Stylesheets
    assert_file "public/stylesheets/scaffold.css"
  end

  def test_scaffold_on_revoke
    run_generator
    run_generator :behavior => :revoke

    # Model
    assert_no_file "app/models/product_line.rb"
    assert_no_file "test/unit/product_line_test.rb"
    assert_no_file "test/fixtures/product_lines.yml"
    assert_no_migration "db/migrate/create_product_lines.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match /map\.resources :product_lines$/, route
    end

    # Controller
    assert_no_file "app/controllers/product_lines_controller.rb"
    assert_no_file "test/functional/product_lines_controller_test.rb"

    # Views
    assert_no_file "app/views/product_lines"
    assert_no_file "app/views/layouts/product_lines.html.erb"

    # Helpers
    assert_no_file "app/helpers/product_lines_helper.rb"
    assert_no_file "test/unit/helpers/product_lines_helper_test.rb"

    # Stylesheets (should not be removed)
    assert_file "public/stylesheets/scaffold.css"
  end

  def test_invoke_output
    output = run_generator
    assert_match /invoke.{4}  active_record/, output
    assert_match /create.{4}    app\/models\/product_line\.rb/, output
  end

  protected

    def run_generator(config={})
      silence(:stdout) do
        Rails::Generators::ScaffoldGenerator.start ["product_line", "title:string", "price:integer"],
                                                   config.merge(:root => destination_root)
      end
    end

end
