require 'generators/generators_test_helper'
require 'rails/generators/rails/scaffold/scaffold_generator'

class ScaffoldGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(product_line title:string product:belongs_to user:references)

  setup :copy_routes

  def test_scaffold_on_invoke
    run_generator

    # Model
    assert_file "app/models/product_line.rb", /class ProductLine < ActiveRecord::Base/
    assert_file "test/models/product_line_test.rb", /class ProductLineTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/product_lines.yml"
    assert_migration "db/migrate/create_product_lines.rb", /belongs_to :product, index: true/
    assert_migration "db/migrate/create_product_lines.rb", /references :user, index: true/

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/resources :product_lines$/, route)
    end

    # Controller
    assert_file "app/controllers/product_lines_controller.rb" do |content|
      assert_match(/class ProductLinesController < ApplicationController/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@product_lines = ProductLine\.all/, m)
      end

      assert_instance_method :show, content

      assert_instance_method :new, content do |m|
        assert_match(/@product_line = ProductLine\.new/, m)
      end

      assert_instance_method :edit, content

      assert_instance_method :create, content do |m|
        assert_match(/@product_line = ProductLine\.new\(product_line_params\)/, m)
        assert_match(/@product_line\.save/, m)
        assert_match(/@product_line\.errors/, m)
      end

      assert_instance_method :update, content do |m|
        assert_match(/@product_line\.update_attributes\(product_line_params\)/, m)
        assert_match(/@product_line\.errors/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@product_line\.destroy/, m)
      end

      assert_instance_method :set_product_line, content do |m|
        assert_match(/@product_line = ProductLine\.find\(params\[:id\]\)/, m)
      end
    end

    assert_file "test/controllers/product_lines_controller_test.rb" do |test|
      assert_match(/class ProductLinesControllerTest < ActionController::TestCase/, test)
      assert_match(/post :create, product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \}/, test)
      assert_match(/put :update, id: @product_line, product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \}/, test)
    end

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/product_lines/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/product_lines.html.erb"

    # Helpers
    assert_file "app/helpers/product_lines_helper.rb"
    assert_file "test/helpers/product_lines_helper_test.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/product_lines.js"
    assert_file "app/assets/stylesheets/product_lines.css"
  end

  def test_functional_tests_without_attributes
    run_generator ["product_line"]

    assert_file "test/controllers/product_lines_controller_test.rb" do |content|
      assert_match(/class ProductLinesControllerTest < ActionController::TestCase/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post :create, product_line: \{  \}/, content)
      assert_match(/put :update, id: @product_line, product_line: \{  \}/, content)
    end
  end

  def test_scaffold_on_revoke
    run_generator
    run_generator ["product_line"], behavior: :revoke

    # Model
    assert_no_file "app/models/product_line.rb"
    assert_no_file "test/models/product_line_test.rb"
    assert_no_file "test/fixtures/product_lines.yml"
    assert_no_migration "db/migrate/create_product_lines.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match(/resources :product_lines$/, route)
    end

    # Controller
    assert_no_file "app/controllers/product_lines_controller.rb"
    assert_no_file "test/controllers/product_lines_controller_test.rb"

    # Views
    assert_no_file "app/views/product_lines"
    assert_no_file "app/views/layouts/product_lines.html.erb"

    # Helpers
    assert_no_file "app/helpers/product_lines_helper.rb"
    assert_no_file "test/helpers/product_lines_helper_test.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css", /:visited/
    assert_no_file "app/assets/javascripts/product_lines.js"
    assert_no_file "app/assets/stylesheets/product_lines.css"
  end

  def test_scaffold_with_namespace_on_invoke
    run_generator [ "admin/role", "name:string", "description:string" ]

    # Model
    assert_file "app/models/admin.rb", /module Admin/
    assert_file "app/models/admin/role.rb", /class Admin::Role < ActiveRecord::Base/
    assert_file "test/models/admin/role_test.rb", /class Admin::RoleTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/admin/roles.yml"
    assert_migration "db/migrate/create_admin_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/^  namespace :admin do\n    resources :roles\n  end$/, route)
    end

    # Controller
    assert_file "app/controllers/admin/roles_controller.rb" do |content|
      assert_match(/class Admin::RolesController < ApplicationController/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@admin_roles = Admin::Role\.all/, m)
      end

      assert_instance_method :show, content

      assert_instance_method :new, content do |m|
        assert_match(/@admin_role = Admin::Role\.new/, m)
      end

      assert_instance_method :edit, content

      assert_instance_method :create, content do |m|
        assert_match(/@admin_role = Admin::Role\.new\(admin_role_params\)/, m)
        assert_match(/@admin_role\.save/, m)
        assert_match(/@admin_role\.errors/, m)
      end

      assert_instance_method :update, content do |m|
        assert_match(/@admin_role\.update_attributes\(admin_role_params\)/, m)
        assert_match(/@admin_role\.errors/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@admin_role\.destroy/, m)
      end

      assert_instance_method :set_admin_role, content do |m|
        assert_match(/@admin_role = Admin::Role\.find\(params\[:id\]\)/, m)
      end
    end

    assert_file "test/controllers/admin/roles_controller_test.rb",
                /class Admin::RolesControllerTest < ActionController::TestCase/

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/admin/roles/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/admin/roles.html.erb"

    # Helpers
    assert_file "app/helpers/admin/roles_helper.rb"
    assert_file "test/helpers/admin/roles_helper_test.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css", /:visited/
    assert_file "app/assets/javascripts/admin/roles.js"
    assert_file "app/assets/stylesheets/admin/roles.css"
  end

  def test_scaffold_with_namespace_on_revoke
    run_generator [ "admin/role", "name:string", "description:string" ]
    run_generator [ "admin/role" ], :behavior => :revoke

    # Model
    assert_file "app/models/admin.rb" # ( should not be remove )
    assert_no_file "app/models/admin/role.rb"
    assert_no_file "test/models/admin/role_test.rb"
    assert_no_file "test/fixtures/admin/roles.yml"
    assert_no_migration "db/migrate/create_admin_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match(/namespace :admin do resources :roles end$/, route)
    end

    # Controller
    assert_no_file "app/controllers/admin/roles_controller.rb"
    assert_no_file "test/controllers/admin/roles_controller_test.rb"

    # Views
    assert_no_file "app/views/admin/roles"
    assert_no_file "app/views/layouts/admin/roles.html.erb"

    # Helpers
    assert_no_file "app/helpers/admin/roles_helper.rb"
    assert_no_file "test/helpers/admin/roles_helper_test.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/admin/roles.js"
    assert_no_file "app/assets/stylesheets/admin/roles.css"
  end

  def test_scaffold_generator_on_revoke_does_not_mutilate_legacy_map_parameter
    run_generator

    # Add a |map| parameter to the routes block manually
    route_path = File.expand_path("config/routes.rb", destination_root)
    content = File.read(route_path).gsub(/\.routes\.draw do/) do |match|
      "#{match} |map|"
    end
    File.open(route_path, "wb") { |file| file.write(content) }

    run_generator ["product_line"], :behavior => :revoke

    assert_file "config/routes.rb", /\.routes\.draw do\s*\|map\|\s*$/
  end

  def test_scaffold_generator_no_assets
    run_generator [ "posts", "--no-assets" ]
    assert_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_no_stylesheets
    run_generator [ "posts", "--no-stylesheets" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_no_html
    run_generator [ "posts", "--no-html" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_generator_no_javascripts
    run_generator [ "posts", "--no-javascripts" ]
    assert_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/posts.js"
    assert_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_outputs_error_message_on_missing_attribute_type
    run_generator ["post", "title", "body:text", "author"]

    assert_migration "db/migrate/create_posts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.string :title/, up)
        assert_match(/t\.text :body/, up)
        assert_match(/t\.string :author/, up)
      end
    end
  end
end
