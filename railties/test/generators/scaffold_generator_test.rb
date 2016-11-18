require "generators/generators_test_helper"
require "rails/generators/rails/scaffold/scaffold_generator"

class ScaffoldGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(product_line title:string product:belongs_to user:references)

  setup :copy_routes

  def test_scaffold_on_invoke
    run_generator

    # Model
    assert_file "app/models/product_line.rb", /class ProductLine < ApplicationRecord/
    assert_file "test/models/product_line_test.rb", /class ProductLineTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/product_lines.yml"
    assert_migration "db/migrate/create_product_lines.rb", /belongs_to :product/
    assert_migration "db/migrate/create_product_lines.rb", /references :user/

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
      end

      assert_instance_method :update, content do |m|
        assert_match(/@product_line\.update\(product_line_params\)/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@product_line\.destroy/, m)
      end

      assert_instance_method :set_product_line, content do |m|
        assert_match(/@product_line = ProductLine\.find\(params\[:id\]\)/, m)
      end
    end

    assert_file "test/controllers/product_lines_controller_test.rb" do |test|
      assert_match(/class ProductLinesControllerTest < ActionDispatch::IntegrationTest/, test)
      assert_match(/post product_lines_url, params: \{ product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \} \}/, test)
      assert_match(/patch product_line_url\(@product_line\), params: \{ product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \} \}/, test)
    end

    # Views
    assert_no_file "app/views/layouts/product_lines.html.erb"

    %w(index show).each do |view|
      assert_file "app/views/product_lines/#{view}.html.erb"
    end

    %w(edit new).each do |view|
      assert_file "app/views/product_lines/#{view}.html.erb", /render 'form', product_line: @product_line/
    end

    assert_file "app/views/product_lines/_form.html.erb" do |test|
      assert_match "product_line", test
      assert_no_match "@product_line", test
    end

    # Helpers
    assert_file "app/helpers/product_lines_helper.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/product_lines.js"
    assert_file "app/assets/stylesheets/product_lines.css"
  end

  def test_api_scaffold_on_invoke
    run_generator %w(product_line title:string product:belongs_to user:references --api --no-template-engine --no-helper --no-assets)

    # Model
    assert_file "app/models/product_line.rb", /class ProductLine < ApplicationRecord/
    assert_file "test/models/product_line_test.rb", /class ProductLineTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/product_lines.yml"
    assert_migration "db/migrate/create_product_lines.rb", /belongs_to :product/
    assert_migration "db/migrate/create_product_lines.rb", /references :user/

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/resources :product_lines$/, route)
    end

    # Controller
    assert_file "app/controllers/product_lines_controller.rb" do |content|
      assert_match(/class ProductLinesController < ApplicationController/, content)
      assert_no_match(/respond_to/, content)

      assert_match(/before_action :set_product_line, only: \[:show, :update, :destroy\]/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@product_lines = ProductLine\.all/, m)
        assert_match(/render json: @product_lines/, m)
      end

      assert_instance_method :show, content do |m|
        assert_match(/render json: @product_line/, m)
      end

      assert_instance_method :create, content do |m|
        assert_match(/@product_line = ProductLine\.new\(product_line_params\)/, m)
        assert_match(/@product_line\.save/, m)
        assert_match(/@product_line\.errors/, m)
      end

      assert_instance_method :update, content do |m|
        assert_match(/@product_line\.update\(product_line_params\)/, m)
        assert_match(/@product_line\.errors/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@product_line\.destroy/, m)
      end
    end

    assert_file "test/controllers/product_lines_controller_test.rb" do |test|
      assert_match(/class ProductLinesControllerTest < ActionDispatch::IntegrationTest/, test)
      assert_match(/post product_lines_url, params: \{ product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \} \}/, test)
      assert_match(/patch product_line_url\(@product_line\), params: \{ product_line: \{ product_id: @product_line\.product_id, title: @product_line\.title, user_id: @product_line\.user_id \} \}/, test)
      assert_no_match(/assert_redirected_to/, test)
    end

    # Views
    assert_no_file "app/views/layouts/product_lines.html.erb"

    %w(index show new edit _form).each do |view|
      assert_no_file "app/views/product_lines/#{view}.html.erb"
    end

    # Helpers
    assert_no_file "app/helpers/product_lines_helper.rb"

    # Assets
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/product_lines.js"
    assert_no_file "app/assets/stylesheets/product_lines.css"
  end

  def test_functional_tests_without_attributes
    run_generator ["product_line"]

    assert_file "test/controllers/product_lines_controller_test.rb" do |content|
      assert_match(/class ProductLinesControllerTest < ActionDispatch::IntegrationTest/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post product_lines_url, params: \{ product_line: \{  \} \}/, content)
      assert_match(/patch product_line_url\(@product_line\), params: \{ product_line: \{  \} \}/, content)
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

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css", /:visited/
    assert_no_file "app/assets/javascripts/product_lines.js"
    assert_no_file "app/assets/stylesheets/product_lines.css"
  end

  def test_scaffold_with_namespace_on_invoke
    run_generator [ "admin/role", "name:string", "description:string" ]

    # Model
    assert_file "app/models/admin.rb", /module Admin/
    assert_file "app/models/admin/role.rb", /class Admin::Role < ApplicationRecord/
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
      end

      assert_instance_method :update, content do |m|
        assert_match(/@admin_role\.update\(admin_role_params\)/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@admin_role\.destroy/, m)
      end

      assert_instance_method :set_admin_role, content do |m|
        assert_match(/@admin_role = Admin::Role\.find\(params\[:id\]\)/, m)
      end
    end

    assert_file "test/controllers/admin/roles_controller_test.rb",
                /class Admin::RolesControllerTest < ActionDispatch::IntegrationTest/

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/admin/roles/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/admin/roles.html.erb"

    # Helpers
    assert_file "app/helpers/admin/roles_helper.rb"

    # Assets
    assert_file "app/assets/stylesheets/scaffold.css", /:visited/
    assert_file "app/assets/javascripts/admin/roles.js"
    assert_file "app/assets/stylesheets/admin/roles.css"
  end

  def test_scaffold_with_namespace_on_revoke
    run_generator [ "admin/role", "name:string", "description:string" ]
    run_generator [ "admin/role" ], behavior: :revoke

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

    run_generator ["product_line"], behavior: :revoke

    assert_file "config/routes.rb", /\.routes\.draw do\s*\|map\|\s*$/
  end

  def test_scaffold_generator_on_revoke_does_not_mutilate_routes
    run_generator

    route_path = File.expand_path("config/routes.rb", destination_root)
    content = File.read(route_path)

    # Remove all of the comments and blank lines from the routes file
    content.gsub!(/^  \#.*\n/, "")
    content.gsub!(/^\n/, "")

    File.open(route_path, "wb") { |file| file.write(content) }
    assert_file "config/routes.rb", /\.routes\.draw do\n  resources :product_lines\nend\n\z/

    run_generator ["product_line"], behavior: :revoke

    assert_file "config/routes.rb", /\.routes\.draw do\nend\n\z/
  end

  def test_scaffold_generator_ignores_commented_routes
    run_generator ["product"]
    assert_file "config/routes.rb", /\.routes\.draw do\n  resources :products\n/
  end

  def test_scaffold_generator_no_assets_with_switch_no_assets
    run_generator [ "posts", "--no-assets" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_no_assets_with_switch_assets_false
    run_generator [ "posts", "--assets=false" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_no_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_no_scaffold_stylesheet_with_switch_no_scaffold_stylesheet
    run_generator [ "posts", "--no-scaffold-stylesheet" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/posts.js"
    assert_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_no_scaffold_stylesheet_with_switch_scaffold_stylesheet_false
    run_generator [ "posts", "--scaffold-stylesheet=false" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/posts.js"
    assert_file "app/assets/stylesheets/posts.css"
  end

  def test_scaffold_generator_with_switch_resource_route_false
    run_generator [ "posts", "--resource-route=false" ]
    assert_file "config/routes.rb" do |route|
      assert_no_match(/resources :posts$/, route)
    end
  end

  def test_scaffold_generator_no_helper_with_switch_no_helper
    output = run_generator [ "posts", "--no-helper" ]

    assert_no_match(/error/, output)
    assert_no_file "app/helpers/posts_helper.rb"
  end

  def test_scaffold_generator_no_helper_with_switch_helper_false
    output = run_generator [ "posts", "--helper=false" ]

    assert_no_match(/error/, output)
    assert_no_file "app/helpers/posts_helper.rb"
  end

  def test_scaffold_generator_no_stylesheets
    run_generator [ "posts", "--no-stylesheets" ]
    assert_no_file "app/assets/stylesheets/scaffold.css"
    assert_file "app/assets/javascripts/posts.js"
    assert_no_file "app/assets/stylesheets/posts.css"
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

  def test_scaffold_generator_belongs_to
    run_generator ["account", "name", "currency:belongs_to"]

    assert_file "app/models/account.rb", /belongs_to :currency/

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.string :name/, up)
        assert_match(/t\.belongs_to :currency/, up)
      end
    end

    assert_file "app/controllers/accounts_controller.rb" do |content|
      assert_instance_method :account_params, content do |m|
        assert_match(/permit\(:name, :currency_id\)/, m)
      end
    end

    assert_file "app/views/accounts/_form.html.erb" do |content|
      assert_match(/^\W{4}<%= f\.text_field :name %>/, content)
      assert_match(/^\W{4}<%= f\.text_field :currency_id %>/, content)
    end
  end

  def test_scaffold_generator_password_digest
    run_generator ["user", "name", "password:digest"]

    assert_file "app/models/user.rb", /has_secure_password/

    assert_migration "db/migrate/create_users.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.string :name/, up)
        assert_match(/t\.string :password_digest/, up)
      end
    end

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_instance_method :user_params, content do |m|
        assert_match(/permit\(:name, :password, :password_confirmation\)/, m)
      end
    end

    assert_file "app/views/users/_form.html.erb" do |content|
      assert_match(/<%= f\.password_field :password %>/, content)
      assert_match(/<%= f\.password_field :password_confirmation %>/, content)
    end

    assert_file "app/views/users/index.html.erb" do |content|
      assert_no_match(/password/, content)
    end

    assert_file "app/views/users/show.html.erb" do |content|
      assert_no_match(/password/, content)
    end

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/password: 'secret'/, content)
      assert_match(/password_confirmation: 'secret'/, content)
    end

    assert_file "test/fixtures/users.yml" do |content|
      assert_match(/password_digest: <%= BCrypt::Password.create\('secret'\) %>/, content)
    end
  end

  def test_scaffold_tests_pass_by_default_inside_mountable_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --mountable` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly do
        `bin/rails g scaffold User name:string age:integer;
        bin/rails db:migrate`
      end
      assert_match(/8 runs, 10 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end

  def test_scaffold_tests_pass_by_default_inside_full_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --full` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly do
        `bin/rails g scaffold User name:string age:integer;
        bin/rails db:migrate`
      end
      assert_match(/8 runs, 10 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end

  def test_scaffold_tests_pass_by_default_inside_api_mountable_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --mountable --api` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly do
        `bin/rails g scaffold User name:string age:integer;
        bin/rails db:migrate`
      end
      assert_match(/6 runs, 8 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end

  def test_scaffold_tests_pass_by_default_inside_api_full_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --full --api` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly do
        `bin/rails g scaffold User name:string age:integer;
        bin/rails db:migrate`
      end
      assert_match(/6 runs, 8 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end
end
