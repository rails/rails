require "generators/generators_test_helper"
require "rails/generators/rails/controller/controller_generator"

class ControllerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(Account foo bar)

  setup :copy_routes

  def test_help_does_not_show_invoked_generators_options_if_they_already_exist
    content = run_generator ["--help"]
    assert_no_match(/Helper options\:/, content)
  end

  def test_controller_skeleton_is_created
    run_generator
    assert_file "app/controllers/account_controller.rb", /class AccountController < ApplicationController/
  end

  def test_check_class_collision
    Object.send :const_set, :ObjectController, Class.new
    content = capture(:stderr) { run_generator ["object"] }
    assert_match(/The name 'ObjectController' is either already used in your application or reserved/, content)
  ensure
    Object.send :remove_const, :ObjectController
  end

  def test_invokes_helper
    run_generator
    assert_file "app/helpers/account_helper.rb"
  end

  def test_does_not_invoke_helper_if_required
    run_generator ["account", "--skip-helper"]
    assert_no_file "app/helpers/account_helper.rb"
  end

  def test_invokes_assets
    run_generator
    assert_file "app/assets/javascripts/account.js"
    assert_file "app/assets/stylesheets/account.css"
  end

  def test_does_not_invoke_assets_if_required
    run_generator ["account", "--skip-assets"]
    assert_no_file "app/assets/javascripts/account.js"
    assert_no_file "app/assets/stylesheets/account.css"
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/controllers/account_controller_test.rb"
  end

  def test_does_not_invoke_test_framework_if_required
    run_generator ["account", "--no-test-framework"]
    assert_no_file "test/controllers/account_controller_test.rb"
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/account/foo.html.erb", %r(app/views/account/foo\.html\.erb)
    assert_file "app/views/account/bar.html.erb", %r(app/views/account/bar\.html\.erb)
  end

  def test_add_routes
    run_generator
    assert_file "config/routes.rb", /get 'account\/foo'/, /get 'account\/bar'/
  end

  def test_skip_routes
    run_generator ["account", "foo", "--skip-routes"]
    assert_file "config/routes.rb" do |routes|
      assert_no_match(/get 'account\/foo'/, routes)
    end
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
      assert_instance_method :foo, controller
      assert_instance_method :bar, controller
    end
  end

  def test_namespaced_routes_are_created_in_routes
    run_generator ["admin/dashboard", "index"]
    assert_file "config/routes.rb" do |route|
      assert_match(/^  namespace :admin do\n    get 'dashboard\/index'\n  end$/, route)
    end
  end
end
