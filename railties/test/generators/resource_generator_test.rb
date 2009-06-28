require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/resource/resource_generator'

# Model
require 'generators/active_record/model/model_generator'
require 'generators/rails/model/model_generator'
require 'generators/test_unit/model/model_generator'

# Controller
require 'generators/erb/controller/controller_generator'
require 'generators/rails/controller/controller_generator'
require 'generators/rails/helper/helper_generator'
require 'generators/test_unit/controller/controller_generator'
require 'generators/test_unit/helper/helper_generator'

class ResourceGeneratorTest < GeneratorsTestCase

  def setup
    super
    routes = Rails::Generators::ResourceGenerator.source_root
    routes = File.join(routes, "..", "..", "app", "templates", "config", "routes.rb")
    destination = File.join(destination_root, "config")

    FileUtils.mkdir_p(destination)
    FileUtils.cp File.expand_path(routes), destination
  end

  def test_help_with_inherited_options
    content = run_generator ["--help"]
    assert_match /ActiveRecord options:/, content
    assert_match /TestUnit options:/, content
  end

  def test_files_from_inherited_invocation
    run_generator

    %w(
      app/models/account.rb
      test/unit/account_test.rb
      test/fixtures/accounts.yml
    ).each { |path| assert_file path }

    assert_migration "db/migrate/create_accounts.rb"
  end

  def test_inherited_invocations_with_attributes
    run_generator ["account", "name:string"]
    assert_migration "db/migrate/create_accounts.rb", /t.string :name/
  end

  def test_resource_controller_with_pluralized_class_name
    run_generator
    assert_file "app/controllers/accounts_controller.rb", /class AccountsController < ApplicationController/
    assert_file "test/functional/accounts_controller_test.rb", /class AccountsControllerTest < ActionController::TestCase/

    assert_file "app/helpers/accounts_helper.rb", /module AccountsHelper/
    assert_file "test/unit/helpers/accounts_helper_test.rb", /class AccountsHelperTest < ActionView::TestCase/
  end

  def test_resource_controller_with_actions
    run_generator ["account", "--actions", "index", "new"]

    assert_file "app/controllers/accounts_controller.rb" do |controller|
      assert_instance_method controller, :index
      assert_instance_method controller, :new
    end

    assert_file "app/views/accounts/index.html.erb"
    assert_file "app/views/accounts/new.html.erb"
  end

  def test_resource_routes_are_added
    run_generator

    assert_file "config/routes.rb" do |route|
      assert_match /map\.resources :accounts$/, route
    end
  end

  protected

    def run_generator(args=["account"])
      silence(:stdout) { Rails::Generators::ResourceGenerator.start args, :root => destination_root }
    end

end
