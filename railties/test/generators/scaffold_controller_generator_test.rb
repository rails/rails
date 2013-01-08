require 'generators/generators_test_helper'
require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

module Unknown
  module Generators
  end
end

class ScaffoldControllerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(User name:string age:integer)

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
      assert_match(/params\[:user\]/, content)
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

  def test_helper_are_invoked_with_a_pluralized_name
    run_generator
    assert_file "app/helpers/users_helper.rb", /module UsersHelper/
    assert_file "test/helpers/users_helper_test.rb", /class UsersHelperTest < ActionView::TestCase/
  end

  def test_views_are_generated
    run_generator

    %w(index edit new show).each do |view|
      assert_file "app/views/users/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/users.html.erb"
  end

  def test_functional_tests
    run_generator ["User", "name:string", "age:integer", "organization:references{polymorphic}"]

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/class UsersControllerTest < ActionController::TestCase/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post :create, user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \}/, content)
      assert_match(/patch :update, id: @user, user: \{ age: @user\.age, name: @user\.name, organization_id: @user\.organization_id, organization_type: @user\.organization_type \}/, content)
    end
  end

  def test_functional_tests_without_attributes
    run_generator ["User"]

    assert_file "test/controllers/users_controller_test.rb" do |content|
      assert_match(/class UsersControllerTest < ActionController::TestCase/, content)
      assert_match(/test "should get index"/, content)
      assert_match(/post :create, user: \{  \}/, content)
      assert_match(/patch :update, id: @user, user: \{  \}/, content)
    end
  end

  def test_skip_helper_if_required
    run_generator ["User", "name:string", "age:integer", "--no-helper"]
    assert_no_file "app/helpers/users_helper.rb"
    assert_no_file "test/helpers/users_helper_test.rb"
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

  def test_new_hash_style
    run_generator
    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match(/render action: 'new'/, content)
    end
  end
end
