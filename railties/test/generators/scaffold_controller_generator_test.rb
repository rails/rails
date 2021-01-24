# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"

module Unknown
  module Generators
  end
end

class ScaffoldControllerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(User name:string age:integer)

  setup :copy_routes

  def test_controller_skeleton_is_created
    run_generator

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/class UsersController < ApplicationController/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@users = User\.all/, m)
      end

      assert_instance_method :show, content

      assert_instance_method :new, content do |m|
        assert_match(/@user = User\.new/, m)
      end

      assert_instance_method :edit, content

      assert_instance_method :create, content do |m|
        assert_match(/@user = User\.new\(user_params\)/, m)
        assert_match(/@user\.save/, m)
      end

      assert_instance_method :update, content do |m|
        assert_match(/@user\.update\(user_params\)/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@user\.destroy/, m)
        assert_match(/User was successfully destroyed/, m)
      end

      assert_instance_method :set_user, content do |m|
        assert_match(/@user = User\.find\(params\[:id\]\)/, m)
      end

      assert_match(/def user_params/, content)
      assert_match(/params\.require\(:user\)\.permit\(:name, :age\)/, content)
    end
  end

  def test_dont_use_require_or_permit_if_there_are_no_attributes
    run_generator ["User"]

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/def user_params/, content)
      assert_match(/params\.fetch\(:user, \{\}\)/, content)
    end
  end

  def test_controller_permit_references_attributes
    run_generator ["LineItem", "product:references", "cart:belongs_to"]

    assert_file "app/controllers/line_items_controller.rb" do |content|
      assert_match(/def line_item_params/, content)
      assert_match(/params\.require\(:line_item\)\.permit\(:product_id, :cart_id\)/, content)
    end
  end

  def test_controller_permit_polymorphic_references_attributes
    run_generator ["LineItem", "product:references{polymorphic}"]

    assert_file "app/controllers/line_items_controller.rb" do |content|
      assert_match(/def line_item_params/, content)
      assert_match(/params\.require\(:line_item\)\.permit\(:product_id, :product_type\)/, content)
    end
  end

  def test_controller_permit_attachment_attributes
    run_generator ["Message", "video:attachment", "photos:attachments"]

    assert_file "app/controllers/messages_controller.rb" do |content|
      assert_match(/def message_params/, content)
      assert_match(/params\.require\(:message\)\.permit\(:video, photos: \[\]\)/, content)
    end
  end

  def test_controller_permit_attachments_attributes_only
    run_generator ["Message", "photos:attachments"]

    assert_file "app/controllers/messages_controller.rb" do |content|
      assert_match(/def message_params/, content)
      assert_match(/params\.require\(:message\)\.permit\(photos: \[\]\)/, content)
    end
  end

  def test_controller_route_are_added
    run_generator ["Message", "photos:attachments"]

    assert_file "config/routes.rb" do |route|
      assert_match(/resources :messages$/, route)
    end
  end

  def test_controller_route_are_skipped
    run_generator ["Message", "photos:attachments", "--skip-routes"]

    assert_file "config/routes.rb" do |route|
      assert_no_match(/resources :messages$/, route)
    end
  end

  def test_helper_are_invoked_with_a_pluralized_name
    run_generator
    assert_file "app/helpers/users_helper.rb", /module UsersHelper/
  end

  def test_views_are_generated
    run_generator

    %w(index edit new show).each do |view|
      assert_file "app/views/users/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/users.html.erb"
  end

  def test_index_page_have_notice
    run_generator

    %w(index show).each do |view|
      assert_file "app/views/users/#{view}.html.erb", /notice/
    end
  end

  def test_functional_tests
    run_generator ["User", "name:string", "age:integer", "organization:references{polymorphic}"]

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/class UsersControllerTest < ActionDispatch::IntegrationTest/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post users_url, params: \{ user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \} \}/, content)
      assert_match(/patch user_url\(@user\), params: \{ user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \} \}/, content)
    end
  end

  def test_functional_tests_without_attributes
    run_generator ["User"]

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/class UsersControllerTest < ActionDispatch::IntegrationTest/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post users_url, params: \{ user: \{  \} \}/, content)
      assert_match(/patch user_url\(@user\), params: \{ user: \{  \} \}/, content)
    end
  end

  def test_skip_helper_if_required
    run_generator ["User", "name:string", "age:integer", "--no-helper"]
    assert_no_file "app/helpers/users_helper.rb"
  end

  def test_skip_layout_if_required
    run_generator ["User", "name:string", "age:integer", "--no-layout"]
    assert_no_file "app/views/layouts/users.html.erb"
  end

  def test_default_orm_is_used
    run_generator ["User", "--orm=unknown"]

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/class UsersController < ApplicationController/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@users = User\.all/, m)
      end
    end
  end

  def test_customized_orm_is_used
    klass = Class.new(Rails::Generators::ActiveModel) do
      def self.all(klass)
        "#{klass}.find(:all)"
      end
    end

    Unknown::Generators.const_set(:ActiveModel, klass)
    run_generator ["User", "--orm=unknown"]

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/class UsersController < ApplicationController/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@users = User\.find\(:all\)/, m)
        assert_no_match(/@users = User\.all/, m)
      end
    end
  ensure
    Unknown::Generators.send :remove_const, :ActiveModel
  end

  def test_model_name_option
    run_generator ["Admin::User", "--model-name=User"]
    assert_file "app/controllers/admin/users_controller.rb" do |content|
      assert_instance_method :index, content do |m|
        assert_match("@users = User.all", m)
      end

      assert_instance_method :create, content do |m|
        assert_match("redirect_to [:admin, @user]", m)
      end

      assert_instance_method :update, content do |m|
        assert_match("redirect_to [:admin, @user]", m)
      end
    end

    assert_file "app/views/admin/users/index.html.erb" do |content|
      assert_match("'New User', new_admin_user_path", content)
    end

    assert_file "app/views/admin/users/new.html.erb" do |content|
      assert_match("\"Back to user\", admin_users_path", content)
    end

    assert_file "app/views/admin/users/_form.html.erb" do |content|
      assert_match("model: [:admin, user]", content)
    end
  end

  def test_controller_tests_pass_by_default_inside_mountable_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --mountable` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly { `bin/rails g controller dashboard foo` }
      quietly { `bin/rails db:migrate RAILS_ENV=test` }
      assert_match(/2 runs, 2 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end

  def test_controller_tests_pass_by_default_inside_full_engine
    Dir.chdir(destination_root) { `bundle exec rails plugin new bukkits --full` }

    engine_path = File.join(destination_root, "bukkits")

    Dir.chdir(engine_path) do
      quietly { `bin/rails g controller dashboard foo` }
      quietly { `bin/rails db:migrate RAILS_ENV=test` }
      assert_match(/2 runs, 2 assertions, 0 failures, 0 errors/, `bin/rails test 2>&1`)
    end
  end

  def test_api_only_generates_a_proper_api_controller
    run_generator ["User", "--api"]

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/class UsersController < ApplicationController/, content)
      assert_no_match(/respond_to/, content)

      assert_match(/before_action :set_user, only: %i\[ show update destroy \]/, content)

      assert_instance_method :index, content do |m|
        assert_match(/@users = User\.all/, m)
        assert_match(/render json: @users/, m)
      end

      assert_instance_method :show, content do |m|
        assert_match(/render json: @user/, m)
      end

      assert_instance_method :create, content do |m|
        assert_match(/@user = User\.new\(user_params\)/, m)
        assert_match(/@user\.save/, m)
        assert_match(/@user\.errors/, m)
      end

      assert_instance_method :update, content do |m|
        assert_match(/@user\.update\(user_params\)/, m)
        assert_match(/@user\.errors/, m)
      end

      assert_instance_method :destroy, content do |m|
        assert_match(/@user\.destroy/, m)
      end
    end

    assert_no_file "app/views/users/index.html.erb"
    assert_no_file "app/views/users/edit.html.erb"
    assert_no_file "app/views/users/show.html.erb"
    assert_no_file "app/views/users/new.html.erb"
    assert_no_file "app/views/users/_form.html.erb"
  end

  def test_api_controller_tests
    run_generator ["User", "name:string", "age:integer", "organization:references{polymorphic}", "--api"]

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/class UsersControllerTest < ActionDispatch::IntegrationTest/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post users_url, params: \{ user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \} \}, as: :json/, content)
      assert_match(/patch user_url\(@user\), params: \{ user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \} \}, as: :json/, content)
      assert_no_match(/assert_redirected_to/, content)
    end
  end

  def test_api_only_generates_params_for_attachments
    run_generator ["Message", "video:attachment", "photos:attachments", "--api"]

    assert_file "app/controllers/messages_controller.rb" do |content|
      assert_match(/def message_params/, content)
      assert_match(/params\.require\(:message\)\.permit\(:video, photos: \[\]\)/, content)
    end
  end

  def test_check_class_collision
    Object.const_set :UsersController, Class.new
    content = capture(:stderr) { run_generator }
    assert_match(/The name 'UsersController' is either already used in your application or reserved/, content)
  ensure
    Object.send :remove_const, :UsersController
  end
end
