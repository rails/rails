require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/scaffold_controller/scaffold_controller_generator'

class ScaffoldControllerGeneratorTest < GeneratorsTestCase

  def test_controller_skeleton_is_created
    run_generator

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_match /class UsersController < ApplicationController/, content

      assert_instance_method content, :index do |m|
        assert_match /@users = User\.all/, m
      end

      assert_instance_method content, :show do |m|
        assert_match /@user = User\.find\(params\[:id\]\)/, m
      end

      assert_instance_method content, :new do |m|
        assert_match /@user = User\.new/, m
      end

      assert_instance_method content, :edit do |m|
        assert_match /@user = User\.find\(params\[:id\]\)/, m
      end

      assert_instance_method content, :create do |m|
        assert_match /@user = User\.new\(params\[:user\]\)/, m
        assert_match /@user\.save/, m
        assert_match /@user\.errors/, m
      end

      assert_instance_method content, :update do |m|
        assert_match /@user = User\.find\(params\[:id\]\)/, m
        assert_match /@user\.update_attributes\(params\[:user\]\)/, m
        assert_match /@user\.errors/, m
      end

      assert_instance_method content, :destroy do |m|
        assert_match /@user = User\.find\(params\[:id\]\)/, m
        assert_match /@user\.destroy/, m
      end
    end
  end

  def test_helper_are_invoked_with_a_pluralized_name
    run_generator
    assert_file "app/helpers/users_helper.rb", /module UsersHelper/
    assert_file "test/unit/helpers/users_helper_test.rb", /class UsersHelperTest < ActionView::TestCase/
  end

  def test_views_are_generated
    run_generator

    %w(
      index
      edit
      new
      show
    ).each { |view| assert_file "app/views/users/#{view}.html.erb" }
    assert_file "app/views/layouts/users.html.erb"
  end

  def test_functional_tests
    run_generator

    assert_file "test/functional/users_controller_test.rb" do |content|
      assert_match /class UsersControllerTest < ActionController::TestCase/, content
      assert_match /test "should get index"/, content
    end
  end

  def test_generates_singleton_controller
    run_generator ["User", "name:string", "age:integer", "--singleton"]

    assert_file "app/controllers/users_controller.rb" do |content|
      assert_no_match /def index/, content
    end

    assert_file "test/functional/users_controller_test.rb" do |content|
      assert_no_match /test "should get index"/, content
    end

    assert_no_file "app/views/users/index.html.erb"
  end

  def test_skip_helper_if_required
    run_generator ["User", "name:string", "age:integer", "--no-helper"]
    assert_no_file "app/helpers/users_helper.rb"
    assert_no_file "test/unit/helpers/users_helper_test.rb"
  end

  def test_skip_layout_if_required
    run_generator ["User", "name:string", "age:integer", "--no-layout"]
    assert_no_file "app/views/layouts/users.html.erb"
  end

  def test_error_is_shown_if_orm_does_not_provide_interface
    error = capture(:stderr){ run_generator ["User", "--orm=unknown"] }
    assert_equal "Could not load Unknown::Generators::ActiveModel, skipping controller. " <<
                 "Error: no such file to load -- generators/unknown.\n", error
  end

  protected

    def run_generator(args=["User", "name:string", "age:integer"])
      silence(:stdout) { Rails::Generators::ScaffoldControllerGenerator.start args, :destination_root => destination_root }
    end

end
