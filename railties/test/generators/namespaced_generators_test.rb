# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/controller/controller_generator"
require "rails/generators/rails/model/model_generator"
require "rails/generators/mailer/mailer_generator"
require "rails/generators/rails/scaffold/scaffold_generator"
require "rails/generators/rails/application_record/application_record_generator"

class NamespacedGeneratorTestCase < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    super
    Rails::Generators.namespace = TestApp
  end
end

class NamespacedControllerGeneratorTest < NamespacedGeneratorTestCase
  arguments %w(Account foo bar)
  tests Rails::Generators::ControllerGenerator

  setup :copy_routes

  def test_namespaced_controller_skeleton_is_created
    run_generator
    assert_file "app/controllers/test_app/account_controller.rb",
                /require_dependency "test_app\/application_controller"/,
                /module TestApp/,
                /  class AccountController < ApplicationController/

    assert_file "test/controllers/test_app/account_controller_test.rb",
                /module TestApp/,
                /  class AccountControllerTest/
  end

  def test_skipping_namespace
    run_generator ["Account", "--skip-namespace"]
    assert_file "app/controllers/account_controller.rb", /class AccountController < ApplicationController/
    assert_file "app/helpers/account_helper.rb", /module AccountHelper/
  end

  def test_namespaced_controller_with_additional_namespace
    run_generator ["admin/account"]
    assert_file "app/controllers/test_app/admin/account_controller.rb", /module TestApp/, /  class Admin::AccountController < ApplicationController/ do |contents|
      assert_match %r(require_dependency "test_app/application_controller"), contents
    end
  end

  def test_helper_is_also_namespaced
    run_generator
    assert_file "app/helpers/test_app/account_helper.rb", /module TestApp/, /  module AccountHelper/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/controllers/test_app/account_controller_test.rb"
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/test_app/account/foo.html.erb", %r(app/views/test_app/account/foo\.html\.erb)
    assert_file "app/views/test_app/account/bar.html.erb", %r(app/views/test_app/account/bar\.html\.erb)
  end

  def test_routes_should_not_be_namespaced
    run_generator
    assert_file "config/routes.rb", /get 'account\/foo'/, /get 'account\/bar'/
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["account"]
    assert_file "app/views/test_app/account"
  end

  def test_namespaced_controller_dont_indent_blank_lines
    run_generator
    assert_file "app/controllers/test_app/account_controller.rb" do |content|
      content.split("\n").each do |line|
        assert_no_match(/^\s+$/, line, "Don't indent blank lines")
      end
    end
  end
end

class NamespacedModelGeneratorTest < NamespacedGeneratorTestCase
  arguments %w(Account name:string age:integer)
  tests Rails::Generators::ModelGenerator

  def test_module_file_is_not_created
    run_generator
    assert_no_file "app/models/test_app.rb"
  end

  def test_adds_namespace_to_model
    run_generator
    assert_file "app/models/test_app/account.rb", /module TestApp/, /  class Account < ApplicationRecord/
  end

  def test_model_with_namespace
    run_generator ["admin/account"]
    assert_file "app/models/test_app/admin.rb", /module TestApp/, /module Admin/
    assert_file "app/models/test_app/admin.rb", /def self\.table_name_prefix/
    assert_file "app/models/test_app/admin.rb", /'test_app_admin_'/
    assert_file "app/models/test_app/admin/account.rb", /module TestApp/, /class Admin::Account < ApplicationRecord/
  end

  def test_migration
    run_generator
    assert_migration "db/migrate/create_test_app_accounts.rb", /create_table :test_app_accounts/, /class CreateTestAppAccounts < ActiveRecord::Migration\[[0-9.]+\]/
  end

  def test_migration_with_namespace
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_test_app_gallery_images", /class CreateTestAppGalleryImages < ActiveRecord::Migration\[[0-9.]+\]/
    assert_no_migration "db/migrate/create_test_app_images"
  end

  def test_migration_with_nested_namespace
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_migration "db/migrate/create_test_app_admin_gallery_images", /class CreateTestAppAdminGalleryImages < ActiveRecord::Migration\[[0-9.]+\]/
    assert_migration "db/migrate/create_test_app_admin_gallery_images", /create_table :test_app_admin_gallery_images/
  end

  def test_migration_with_nested_namespace_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_no_migration "db/migrate/create_test_app_admin_gallery_images"
    assert_migration "db/migrate/create_test_app_admin_gallery_image", /class CreateTestAppAdminGalleryImage < ActiveRecord::Migration\[[0-9.]+\]/
    assert_migration "db/migrate/create_test_app_admin_gallery_image", /create_table :test_app_admin_gallery_image/
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/models/test_app/account_test.rb", /module TestApp/, /class AccountTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/accounts.yml", /name: MyString/, /age: 1/
  end
end

class NamespacedMailerGeneratorTest < NamespacedGeneratorTestCase
  arguments %w(notifier foo bar)
  tests Rails::Generators::MailerGenerator

  def test_mailer_skeleton_is_created
    run_generator
    assert_file "app/mailers/test_app/notifier_mailer.rb" do |mailer|
      assert_match(/module TestApp/, mailer)
      assert_match(/class NotifierMailer < ApplicationMailer/, mailer)
      assert_no_match(/default from: "from@example\.com"/, mailer)
    end
  end

  def test_mailer_with_i18n_helper
    run_generator
    assert_file "app/mailers/test_app/notifier_mailer.rb" do |mailer|
      assert_match(/en\.notifier_mailer\.foo\.subject/, mailer)
      assert_match(/en\.notifier_mailer\.bar\.subject/, mailer)
    end
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/mailers/test_app/notifier_mailer_test.rb" do |test|
      assert_match(/module TestApp/, test)
      assert_match(/class NotifierMailerTest < ActionMailer::TestCase/, test)
      assert_match(/test "foo"/, test)
      assert_match(/test "bar"/, test)
    end
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/test_app/notifier_mailer/foo.text.erb" do |view|
      assert_match(%r(app/views/test_app/notifier_mailer/foo\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/test_app/notifier_mailer/bar.text.erb" do |view|
      assert_match(%r(app/views/test_app/notifier_mailer/bar\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["notifier"]
    assert_file "app/views/test_app/notifier_mailer"
  end
end

class NamespacedScaffoldGeneratorTest < NamespacedGeneratorTestCase
  include GeneratorsTestHelper
  arguments %w(product_line title:string price:integer)
  tests Rails::Generators::ScaffoldGenerator

  setup :copy_routes

  def test_scaffold_on_invoke
    run_generator

    # Model
    assert_file "app/models/test_app/product_line.rb", /module TestApp\n  class ProductLine < ApplicationRecord/
    assert_file "test/models/test_app/product_line_test.rb", /module TestApp\n  class ProductLineTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/product_lines.yml"
    assert_migration "db/migrate/create_test_app_product_lines.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/resources :product_lines$/, route)
    end

    # Controller
    assert_file "app/controllers/test_app/product_lines_controller.rb",
                /require_dependency "test_app\/application_controller"/,
                /module TestApp/,
                /class ProductLinesController < ApplicationController/

    assert_file "test/controllers/test_app/product_lines_controller_test.rb",
                /module TestApp\n  class ProductLinesControllerTest < ActionDispatch::IntegrationTest/

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/test_app/product_lines/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/test_app/product_lines.html.erb"

    # Helpers
    assert_file "app/helpers/test_app/product_lines_helper.rb"

    # Stylesheets
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_on_revoke
    run_generator
    run_generator ["product_line"], behavior: :revoke

    # Model
    assert_no_file "app/models/test_app/product_line.rb"
    assert_no_file "test/models/test_app/product_line_test.rb"
    assert_no_file "test/fixtures/test_app/product_lines.yml"
    assert_no_migration "db/migrate/create_test_app_product_lines.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match(/resources :product_lines$/, route)
    end

    # Controller
    assert_no_file "app/controllers/test_app/product_lines_controller.rb"
    assert_no_file "test/controllers/test_app/product_lines_controller_test.rb"

    # Views
    assert_no_file "app/views/test_app/product_lines"
    assert_no_file "app/views/test_app/layouts/product_lines.html.erb"

    # Helpers
    assert_no_file "app/helpers/test_app/product_lines_helper.rb"

    # Stylesheets (should not be removed)
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_with_namespace_on_invoke
    run_generator [ "admin/role", "name:string", "description:string" ]

    # Model
    assert_file "app/models/test_app/admin.rb", /module TestApp\n  module Admin/
    assert_file "app/models/test_app/admin/role.rb", /module TestApp\n  class Admin::Role < ApplicationRecord/
    assert_file "test/models/test_app/admin/role_test.rb", /module TestApp\n  class Admin::RoleTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/admin/roles.yml"
    assert_migration "db/migrate/create_test_app_admin_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/^  namespace :admin do\n    resources :roles\n  end$/, route)
    end

    # Controller
    assert_file "app/controllers/test_app/admin/roles_controller.rb" do |content|
      assert_match(/module TestApp\n  class Admin::RolesController < ApplicationController/, content)
      assert_match(%r(require_dependency "test_app/application_controller"), content)
    end

    assert_file "test/controllers/test_app/admin/roles_controller_test.rb",
                /module TestApp\n  class Admin::RolesControllerTest < ActionDispatch::IntegrationTest/

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/test_app/admin/roles/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/admin/roles.html.erb"

    # Helpers
    assert_file "app/helpers/test_app/admin/roles_helper.rb"

    # Stylesheets
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_with_namespace_on_revoke
    run_generator [ "admin/role", "name:string", "description:string" ]
    run_generator [ "admin/role" ], behavior: :revoke

    # Model
    assert_file "app/models/test_app/admin.rb"  # ( should not be remove )
    assert_no_file "app/models/test_app/admin/role.rb"
    assert_no_file "test/models/test_app/admin/role_test.rb"
    assert_no_file "test/fixtures/test_app/admin/roles.yml"
    assert_no_migration "db/migrate/create_test_app_admin_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match(/^  namespace :admin do\n    resources :roles\n  end$$/, route)
    end

    # Controller
    assert_no_file "app/controllers/test_app/admin/roles_controller.rb"
    assert_no_file "test/controllers/test_app/admin/roles_controller_test.rb"

    # Views
    assert_no_file "app/views/test_app/admin/roles"
    assert_no_file "app/views/layouts/test_app/admin/roles.html.erb"

    # Helpers
    assert_no_file "app/helpers/test_app/admin/roles_helper.rb"

    # Stylesheets (should not be removed)
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_with_nested_namespace_on_invoke
    run_generator [ "admin/user/special/role", "name:string", "description:string" ]

    # Model
    assert_file "app/models/test_app/admin/user/special.rb", /module TestApp\n  module Admin/
    assert_file "app/models/test_app/admin/user/special/role.rb", /module TestApp\n  class Admin::User::Special::Role < ApplicationRecord/
    assert_file "test/models/test_app/admin/user/special/role_test.rb", /module TestApp\n  class Admin::User::Special::RoleTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/admin/user/special/roles.yml"
    assert_migration "db/migrate/create_test_app_admin_user_special_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/^  namespace :admin do\n    namespace :user do\n      namespace :special do\n        resources :roles\n      end\n    end\n  end$/, route)
    end

    # Controller
    assert_file "app/controllers/test_app/admin/user/special/roles_controller.rb" do |content|
      assert_match(/module TestApp\n  class Admin::User::Special::RolesController < ApplicationController/, content)
    end

    assert_file "test/controllers/test_app/admin/user/special/roles_controller_test.rb",
                /module TestApp\n  class Admin::User::Special::RolesControllerTest < ActionDispatch::IntegrationTest/

    # Views
    %w(index edit new show _form).each do |view|
      assert_file "app/views/test_app/admin/user/special/roles/#{view}.html.erb"
    end
    assert_no_file "app/views/layouts/admin/user/special/roles.html.erb"

    # Helpers
    assert_file "app/helpers/test_app/admin/user/special/roles_helper.rb"

    # Stylesheets
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_scaffold_with_nested_namespace_on_revoke
    run_generator [ "admin/user/special/role", "name:string", "description:string" ]
    run_generator [ "admin/user/special/role" ], behavior: :revoke

    # Model
    assert_file "app/models/test_app/admin/user/special.rb"  # ( should not be remove )
    assert_no_file "app/models/test_app/admin/user/special/role.rb"
    assert_no_file "test/models/test_app/admin/user/special/role_test.rb"
    assert_no_file "test/fixtures/test_app/admin/user/special/roles.yml"
    assert_no_migration "db/migrate/create_test_app_admin_user_special_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_no_match(/^  namespace :admin do\n    namespace :user do\n      namespace :special do\n        resources :roles\n      end\n    end\n  end$/, route)
    end

    # Controller
    assert_no_file "app/controllers/test_app/admin/user/special/roles_controller.rb"
    assert_no_file "test/controllers/test_app/admin/user/special/roles_controller_test.rb"

    # Views
    assert_no_file "app/views/test_app/admin/user/special/roles"

    # Helpers
    assert_no_file "app/helpers/test_app/admin/user/special/roles_helper.rb"

    # Stylesheets (should not be removed)
    assert_file "app/assets/stylesheets/scaffold.css"
  end

  def test_api_scaffold_with_namespace_on_invoke
    run_generator [ "admin/role", "name:string", "description:string", "--api" ]

    # Model
    assert_file "app/models/test_app/admin.rb", /module TestApp\n  module Admin/
    assert_file "app/models/test_app/admin/role.rb", /module TestApp\n  class Admin::Role < ApplicationRecord/
    assert_file "test/models/test_app/admin/role_test.rb", /module TestApp\n  class Admin::RoleTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/test_app/admin/roles.yml"
    assert_migration "db/migrate/create_test_app_admin_roles.rb"

    # Route
    assert_file "config/routes.rb" do |route|
      assert_match(/^  namespace :admin do\n    resources :roles\n  end$/, route)
    end

    # Controller
    assert_file "app/controllers/test_app/admin/roles_controller.rb" do |content|
      assert_match(/module TestApp\n  class Admin::RolesController < ApplicationController/, content)
      assert_match(%r(require_dependency "test_app/application_controller"), content)
    end
    assert_file "test/controllers/test_app/admin/roles_controller_test.rb",
                /module TestApp\n  class Admin::RolesControllerTest < ActionDispatch::IntegrationTest/
  end
end

class NamespacedApplicationRecordGeneratorTest < NamespacedGeneratorTestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ApplicationRecordGenerator

  def test_adds_namespace_to_application_record
    run_generator
    assert_file "app/models/test_app/application_record.rb", /module TestApp/, /  class ApplicationRecord < ActiveRecord::Base/
  end
end
