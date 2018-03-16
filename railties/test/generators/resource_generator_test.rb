# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/resource/resource_generator"

class ResourceGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(account)

  setup :copy_routes

  def test_help_with_inherited_options
    content = run_generator ["--help"]
    assert_match(/ActiveRecord options:/, content)
    assert_match(/TestUnit options:/, content)
  end

  def test_files_from_inherited_invocation
    run_generator

    %w(
      app/models/account.rb
      test/models/account_test.rb
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
    assert_file "test/controllers/accounts_controller_test.rb", /class AccountsControllerTest < ActionDispatch::IntegrationTest/

    assert_file "app/helpers/accounts_helper.rb", /module AccountsHelper/
  end

  def test_resource_controller_with_actions
    run_generator ["account", "--actions", "index", "new"]

    assert_file "app/controllers/accounts_controller.rb" do |controller|
      assert_instance_method :index, controller
      assert_instance_method :new, controller
    end

    assert_file "app/views/accounts/index.html.erb"
    assert_file "app/views/accounts/new.html.erb"
  end

  def test_resource_routes_are_added
    run_generator

    assert_file "config/routes.rb" do |route|
      assert_match(/resources :accounts$/, route)
    end
  end

  def test_plural_names_are_singularized
    content = run_generator ["accounts"]
    assert_file "app/models/account.rb", /class Account < ApplicationRecord/
    assert_file "test/models/account_test.rb", /class AccountTest/
    assert_match(/\[WARNING\] The model name 'accounts' was recognized as a plural, using the singular 'account' instead\. Override with --force-plural or setup custom inflection rules for this noun before running the generator\./, content)
  end

  def test_plural_names_can_be_forced
    content = run_generator ["accounts", "--force-plural"]
    assert_file "app/models/accounts.rb", /class Accounts < ApplicationRecord/
    assert_file "test/models/accounts_test.rb", /class AccountsTest/
    assert_no_match(/\[WARNING\]/, content)
  end

  def test_mass_nouns_do_not_throw_warnings
    content = run_generator ["sheep"]
    assert_no_match(/\[WARNING\]/, content)
  end

  def test_route_is_removed_on_revoke
    run_generator
    run_generator ["account"], behavior: :revoke

    assert_file "config/routes.rb" do |route|
      assert_no_match(/resources :accounts$/, route)
    end
  end
end
