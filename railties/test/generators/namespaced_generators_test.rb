require 'generators/generators_test_helper'
require 'rails/generators/rails/controller/controller_generator'
require 'rails/generators/rails/model/model_generator'
require 'rails/generators/rails/observer/observer_generator'

class NamespacedGeneratorTestCase < Rails::Generators::TestCase
  def setup
    TestApp::Application.namespace(TestApp)
  end

  def teardown
    if TestApp.respond_to?(:_railtie)
      TestApp.singleton_class.send(:undef_method, :_railtie)
      TestApp.singleton_class.send(:undef_method, :table_name_prefix)
      TestApp::Application.namespaced = false
    end
  end
end

class NamespacedControllerGeneratorTest < NamespacedGeneratorTestCase
  include GeneratorsTestHelper
  arguments %w(Account foo bar)
  tests Rails::Generators::ControllerGenerator

  setup :copy_routes

  def test_namespaced_controller_skeleton_is_created
    run_generator
    assert_file "app/controllers/test_app/account_controller.rb", /module TestApp/, /  class AccountController < ApplicationController/
    assert_file "test/functional/test_app/account_controller_test.rb", /module TestApp/, /  class AccountControllerTest/
  end

  def test_skipping_namespace
    run_generator ["Account", "--skip-namespace"]
    assert_file "app/controllers/account_controller.rb", /class AccountController < ApplicationController/
    assert_file "app/helpers/account_helper.rb", /module AccountHelper/
  end

  def test_namespaced_controller_with_additional_namespace
    run_generator ["admin/account"]
    assert_file "app/controllers/test_app/admin/account_controller.rb", /module TestApp/, /  class Admin::AccountController < ApplicationController/
  end

  def test_helpr_is_also_namespaced
    run_generator
    assert_file "app/helpers/test_app/account_helper.rb", /module TestApp/, /  module AccountHelper/
    assert_file "test/unit/helpers/test_app/account_helper_test.rb", /module TestApp/, /  class AccountHelperTest/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/functional/test_app/account_controller_test.rb"
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/test_app/account/foo.html.erb", %r(app/views/test_app/account/foo\.html\.erb)
    assert_file "app/views/test_app/account/bar.html.erb", %r(app/views/test_app/account/bar\.html\.erb)
  end

  def test_routes_should_not_be_namespaced
    run_generator
    assert_file "config/routes.rb", /get "account\/foo"/, /get "account\/bar"/
  end
#
  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["account"]
    assert_file "app/views/test_app/account"
  end
end

class NamespacedModelGeneratorTest < NamespacedGeneratorTestCase
  include GeneratorsTestHelper
  arguments %w(Account name:string age:integer)
  tests Rails::Generators::ModelGenerator

  def test_module_file_is_not_created
    run_generator
    assert_no_file "app/models/test_app.rb"
  end

  def test_adds_namespace_to_model
    run_generator
    assert_file "app/models/test_app/account.rb", /module TestApp/, /  class Account < ActiveRecord::Base/
  end

  def test_model_with_namespace
    run_generator ["admin/account"]
    assert_file "app/models/test_app/admin.rb", /module TestApp/, /module Admin/
    assert_file "app/models/test_app/admin.rb", /def self\.table_name_prefix/
    assert_file "app/models/test_app/admin.rb", /'admin_'/
    assert_file "app/models/test_app/admin/account.rb", /module TestApp/, /class Admin::Account < ActiveRecord::Base/
  end

  def test_migration
    run_generator
    assert_migration "db/migrate/create_test_app_accounts.rb", /create_table :test_app_accounts/, /class CreateTestAppAccounts < ActiveRecord::Migration/
  end

  def test_migration_with_namespace
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_test_app_gallery_images", /class CreateTestAppGalleryImages < ActiveRecord::Migration/
    assert_no_migration "db/migrate/create_test_app_images"
  end

  def test_migration_with_nested_namespace
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_migration "db/migrate/create_test_app_admin_gallery_images", /class CreateTestAppAdminGalleryImages < ActiveRecord::Migration/
    assert_migration "db/migrate/create_test_app_admin_gallery_images", /create_table :test_app_admin_gallery_images/
  end

  def test_migration_with_nested_namespace_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_no_migration "db/migrate/create_test_app_admin_gallery_images"
    assert_migration "db/migrate/create_test_app_admin_gallery_image", /class CreateTestAppAdminGalleryImage < ActiveRecord::Migration/
    assert_migration "db/migrate/create_test_app_admin_gallery_image", /create_table :test_app_admin_gallery_image/
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/test_app/account_test.rb", /module TestApp/, /class AccountTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/accounts.yml", /name: MyString/, /age: 1/
  end
end

class NamespacedObserverGeneratorTest < NamespacedGeneratorTestCase
  include GeneratorsTestHelper
  arguments %w(account)
  tests Rails::Generators::ObserverGenerator

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/test_app/account_observer.rb", /module TestApp/, /  class AccountObserver < ActiveRecord::Observer/
  end

  def test_invokes_default_orm_with_class_path
    run_generator ["admin/account"]
    assert_file "app/models/test_app/admin/account_observer.rb", /module TestApp/, /  class Admin::AccountObserver < ActiveRecord::Observer/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/test_app/account_observer_test.rb", /module TestApp/, /  class AccountObserverTest < ActiveSupport::TestCase/
  end
end
