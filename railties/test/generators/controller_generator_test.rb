require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/controller/controller_generator'

class ControllerGeneratorTest < GeneratorsTestCase

  def test_help_does_not_show_invoked_generators_options_if_they_already_exist
    content = run_generator ["--help"]
    assert_no_match /Helper options:/, content
  end

  def test_controller_skeleton_is_created
    run_generator
    assert_file "app/controllers/account_controller.rb", /class AccountController < ApplicationController/
  end

  def test_check_class_collision
    Object.send :const_set, :ObjectController, Class.new
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'ObjectController' is either already used in your application or reserved/, content
  ensure
    Object.send :remove_const, :ObjectController
  end

  # No need to spec content since it's already spec'ed on helper generator.
  #
  def test_invokes_helper
    run_generator
    assert_file "app/helpers/account_helper.rb"
    assert_file "test/unit/helpers/account_helper_test.rb"
  end

  def test_does_not_invoke_helper_if_required
    run_generator ["account", "--skip-helper"]
    assert_no_file "app/helpers/account_helper.rb"
    assert_no_file "test/unit/helpers/account_helper_test.rb"
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/functional/account_controller_test.rb"
  end

  def test_does_not_invoke_test_framework_if_required
    run_generator ["account", "--no-test-framework"]
    assert_no_file "test/functional/account_controller_test.rb"
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/account/foo.html.erb", /app\/views\/account\/foo/
    assert_file "app/views/account/bar.html.erb", /app\/views\/account\/bar/
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["account"]
    assert_file "app/views/account"
  end

  def test_template_engine_with_class_path
    run_generator ["admin/account"]
    assert_file "app/views/admin/account"
  end

  def test_actions_are_turned_into_methods
    run_generator

    assert_file "app/controllers/account_controller.rb" do |controller|
      assert_instance_method controller, :foo
      assert_instance_method controller, :bar
    end
  end

  protected

    def run_generator(args=["Account", "foo", "bar"])
      silence(:stdout) { Rails::Generators::ControllerGenerator.start args, :destination_root => destination_root }
    end

end
