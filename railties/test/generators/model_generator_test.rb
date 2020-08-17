# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/model/model_generator"

class ModelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(Account name:string age:integer)

  def setup
    super
    Rails::Generators::ModelHelpers.skip_warn = false
    @old_belongs_to_required_by_default = Rails.application.config.active_record.belongs_to_required_by_default

    Rails.application.config.active_record.belongs_to_required_by_default = true
  end


  def teardown
    Rails.application.config.active_record.belongs_to_required_by_default = @old_belongs_to_required_by_default
  end

  def test_help_shows_invoked_generators_options
    content = run_generator ["--help"]
    assert_match(/ActiveRecord options:/, content)
    assert_match(/TestUnit options:/, content)
  end

  def test_model_with_missing_attribute_type
    run_generator ["post", "title", "body:text", "author"]

    assert_migration "db/migrate/create_posts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.string :title/, up)
        assert_match(/t\.text :body/, up)
        assert_match(/t\.string :author/, up)
      end
    end
  end

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/account.rb", /class Account < ApplicationRecord/
  end

  def test_model_with_parent_option
    run_generator ["account", "--parent", "Admin::Account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_model_with_database_option
    with_database_configuration do
      run_generator ["account", "--database", "secondary"]
      assert_file "app/models/secondary_record.rb", /class SecondaryRecord < ApplicationRecord/
      assert_file "app/models/account.rb", /class Account < SecondaryRecord/
      assert_migration "db/secondary_migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/
    end
  end

  def test_model_with_parent_and_database_option
    with_database_configuration do
      run_generator ["account", "--parent", "Admin::Account", "--database", "secondary"]
      assert_file "app/models/account.rb", /class Account < Admin::Account/
      assert_migration "db/secondary_migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/
    end
  end

  def test_model_with_no_migration_and_database_option
    with_database_configuration do
      run_generator ["account", "--migration", "false", "--database", "secondary"]
      assert_file "app/models/account.rb", /class Account < SecondaryRecord/
      assert_no_migration "db/secondary_migrate/create_accounts.rb"
    end
  end

  def test_model_with_no_migration_option
    run_generator ["account", "--migration", "false"]
    assert_file "app/models/account.rb", /class Account < ApplicationRecord/
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_model_with_parent_option_database_option_and_no_migration_option
    with_database_configuration do
      run_generator ["account", "--migration", "false", "--database", "secondary", "--migration", "false", "--parent", "Admin::Account"]
      assert_file "app/models/account.rb", /class Account < Admin::Account/
      assert_no_migration "db/secondary_migrate/create_accounts.rb"
    end
  end

  def test_model_with_underscored_database_option
    with_database_configuration("admin_accounts") do
      run_generator ["account", "--database", "admin_accounts"]
      assert_file "app/models/admin_accounts_record.rb", /class AdminAccountsRecord < ApplicationRecord/
      assert_file "app/models/account.rb", /class Account < AdminAccountsRecord/
      assert_migration "db/admin_accounts_migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/
    end
  end

  def test_plural_names_are_singularized
    content = run_generator ["accounts"]
    assert_file "app/models/account.rb", /class Account < ApplicationRecord/
    assert_file "test/models/account_test.rb", /class AccountTest/
    assert_match(/\[WARNING\] The model name 'accounts' was recognized as a plural, using the singular 'account' instead\. Override with --force-plural or setup custom inflection rules for this noun before running the generator\./, content)
  end

  def test_unknown_inflection_rule_are_warned
    content = run_generator ["porsche"]
    assert_match("[WARNING] Rails cannot recover singular form from its plural form 'porsches'.\nPlease setup custom inflection rules for this noun before running the generator in config/initializers/inflections.rb.", content)
    assert_file "app/models/porsche.rb", /class Porsche < ApplicationRecord/

    uncountable_content = run_generator ["sheep"]
    assert_no_match("[WARNING] Rails cannot recover singular form from its plural form", uncountable_content)

    regular_content = run_generator ["account"]
    assert_no_match("[WARNING] Rails cannot recover singular form from its plural form", regular_content)
  end

  def test_model_with_underscored_parent_option
    run_generator ["account", "--parent", "admin/account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_model_with_namespace
    run_generator ["admin/account"]
    assert_file "app/models/admin.rb", /module Admin/
    assert_file "app/models/admin.rb", /def self\.table_name_prefix/
    assert_file "app/models/admin.rb", /'admin_'/
    assert_file "app/models/admin/account.rb", /class Admin::Account < ApplicationRecord/
  end

  def test_migration
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/
  end

  def test_migration_with_namespace
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_gallery_images", /class CreateGalleryImages < ActiveRecord::Migration\[[0-9.]+\]/
    assert_no_migration "db/migrate/create_images"
  end

  def test_migration_with_nested_namespace
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_migration "db/migrate/create_admin_gallery_images", /class CreateAdminGalleryImages < ActiveRecord::Migration\[[0-9.]+\]/
    assert_migration "db/migrate/create_admin_gallery_images", /create_table :admin_gallery_images/
  end

  def test_migration_with_nested_namespace_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_no_migration "db/migrate/create_admin_gallery_images"
    assert_migration "db/migrate/create_admin_gallery_image", /class CreateAdminGalleryImage < ActiveRecord::Migration\[[0-9.]+\]/
    assert_migration "db/migrate/create_admin_gallery_image", /create_table :admin_gallery_image/
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_with_namespaces_in_model_name_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_gallery_image", /class CreateGalleryImage < ActiveRecord::Migration\[[0-9.]+\]/
    assert_no_migration "db/migrate/create_gallery_images"
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator
    assert_migration "db/migrate/create_account", /class CreateAccount < ActiveRecord::Migration\[[0-9.]+\]/
    assert_no_migration "db/migrate/create_accounts"
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_is_skipped
    run_generator ["account", "--no-migration"]
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_migration_with_attributes
    run_generator ["product", "name:string", "supplier_id:integer"]

    assert_migration "db/migrate/create_products.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/create_table :products/, up)
        assert_match(/t\.string :name/, up)
        assert_match(/t\.integer :supplier_id/, up)
      end
    end
  end

  def test_migration_with_attributes_and_with_index
    run_generator ["product", "name:string:index", "supplier_id:integer:index", "user_id:integer:uniq", "order_id:uniq"]

    assert_migration "db/migrate/create_products.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/create_table :products/, up)
        assert_match(/t\.string :name/, up)
        assert_match(/t\.integer :supplier_id/, up)
        assert_match(/t\.integer :user_id/, up)
        assert_match(/t\.string :order_id/, up)

        assert_match(/add_index :products, :name/, up)
        assert_match(/add_index :products, :supplier_id/, up)
        assert_match(/add_index :products, :user_id, unique: true/, up)
        assert_match(/add_index :products, :order_id, unique: true/, up)
      end
    end
  end

  def test_migration_with_attributes_and_with_wrong_index_declaration
    run_generator ["product", "name:string", "supplier_id:integer:inex", "user_id:integer:unqu"]

    assert_migration "db/migrate/create_products.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/create_table :products/, up)
        assert_match(/t\.string :name/, up)
        assert_match(/t\.integer :supplier_id/, up)
        assert_match(/t\.integer :user_id/, up)

        assert_no_match(/add_index :products, :name/, up)
        assert_no_match(/add_index :products, :supplier_id/, up)
        assert_no_match(/add_index :products, :user_id/, up)
      end
    end
  end

  def test_migration_with_missing_attribute_type_and_with_index
    run_generator ["product", "name:index", "supplier_id:integer:index", "year:integer"]

    assert_migration "db/migrate/create_products.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/create_table :products/, up)
        assert_match(/t\.string :name/, up)
        assert_match(/t\.integer :supplier_id/, up)

        assert_match(/add_index :products, :name/, up)
        assert_match(/add_index :products, :supplier_id/, up)
        assert_no_match(/add_index :products, :year/, up)
      end
    end
  end

  def test_add_migration_with_attributes_index_declaration_and_attribute_options
    run_generator ["product", "title:string{40}:index", "content:string{255}", "price:decimal{5,2}:index", "discount:decimal{5,2}:uniq", "supplier:references{polymorphic}"]

    assert_migration "db/migrate/create_products.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/create_table :products/, up)
        assert_match(/t.string :title, limit: 40/, up)
        assert_match(/t.string :content, limit: 255/, up)
        assert_match(/t.decimal :price, precision: 5, scale: 2/, up)
        assert_match(/t.references :supplier, polymorphic: true/, up)
      end
      assert_match(/add_index :products, :title/, content)
      assert_match(/add_index :products, :price/, content)
      assert_match(/add_index :products, :discount, unique: true/, content)
    end
  end

  def test_migration_without_timestamps
    ActiveRecord::Base.timestamped_migrations = false
    run_generator ["account"]
    assert_file "db/migrate/001_create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/

    run_generator ["project"]
    assert_file "db/migrate/002_create_projects.rb", /class CreateProjects < ActiveRecord::Migration\[[0-9.]+\]/
  ensure
    ActiveRecord::Base.timestamped_migrations = true
  end

  def test_migration_with_configured_path
    old_paths = Rails.application.config.paths["db/migrate"]
    Rails.application.config.paths.add "db/migrate", with: "db2/migrate"

    run_generator

    assert_migration "db2/migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration\[[0-9.]+\]/
  ensure
    Rails.application.config.paths["db/migrate"] = old_paths
  end

  def test_model_with_references_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier:references"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_model_with_belongs_to_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier:belongs_to"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_model_with_polymorphic_references_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier:references{polymorphic}"]
    assert_file "app/models/product.rb", /belongs_to :supplier, polymorphic: true/
  end

  def test_model_with_polymorphic_belongs_to_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier:belongs_to{polymorphic}"]
    assert_file "app/models/product.rb", /belongs_to :supplier, polymorphic: true/
  end

  def test_migration_with_timestamps
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /t\.timestamps/
  end

  def test_migration_timestamps_are_skipped
    run_generator ["account", "--no-timestamps"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match(/t\.timestamps/, up)
      end
    end
  end

  def test_migration_is_skipped_with_skip_option
    run_generator
    output = run_generator ["Account", "--skip"]
    assert_match %r{skip\s+db/migrate/\d+_create_accounts\.rb}, output
  end

  def test_migration_is_ignored_as_identical_with_skip_option
    run_generator ["Account"]
    output = run_generator ["Account", "--skip"]
    assert_match %r{identical\s+db/migrate/\d+_create_accounts\.rb}, output
  end

  def test_migration_is_skipped_on_skip_behavior
    run_generator
    output = run_generator ["Account"], behavior: :skip
    assert_match %r{skip\s+db/migrate/\d+_create_accounts\.rb}, output
  end

  def test_migration_error_is_not_shown_on_revoke
    run_generator
    error = capture(:stderr) { run_generator ["Account"], behavior: :revoke }
    assert_no_match(/Another migration is already named create_accounts/, error)
  end

  def test_migration_is_removed_on_revoke
    run_generator
    run_generator ["Account"], behavior: :revoke
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_existing_migration_is_removed_on_force
    run_generator
    old_migration = Dir["#{destination_root}/db/migrate/*_create_accounts.rb"].first
    error = capture(:stderr) { run_generator ["Account", "--force"] }
    assert_no_match(/Another migration is already named create_accounts/, error)
    assert_no_file old_migration
    assert_migration "db/migrate/create_accounts.rb"
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/models/account_test.rb", /class AccountTest < ActiveSupport::TestCase/

    assert_file "test/fixtures/accounts.yml", /name: MyString/, /age: 1/
    assert_generated_fixture("test/fixtures/accounts.yml",
                             "one" => { "name" => "MyString", "age" => 1 }, "two" => { "name" => "MyString", "age" => 1 })
  end

  def test_fixtures_use_the_references_ids
    run_generator ["LineItem", "product:references", "cart:belongs_to"]

    assert_file "test/fixtures/line_items.yml", /product: one\n  cart: one/
    assert_generated_fixture("test/fixtures/line_items.yml",
                             "one" => { "product" => "one", "cart" => "one" }, "two" => { "product" => "two", "cart" => "two" })
  end

  def test_fixtures_use_the_references_ids_and_type
    run_generator ["LineItem", "product:references{polymorphic}", "cart:belongs_to"]

    assert_file "test/fixtures/line_items.yml", /product: one\n  product_type: Product\n  cart: one/
    assert_generated_fixture("test/fixtures/line_items.yml",
                             "one" => { "product" => "one", "product_type" => "Product", "cart" => "one" },
                              "two" => { "product" => "two", "product_type" => "Product", "cart" => "two" })
  end

  def test_fixtures_respect_reserved_yml_keywords
    run_generator ["LineItem", "no:integer", "Off:boolean", "ON:boolean"]

    assert_generated_fixture("test/fixtures/line_items.yml",
                             "one" => { "no" => 1, "Off" => false, "ON" => false }, "two" => { "no" => 1, "Off" => false, "ON" => false })
  end

  def test_fixture_is_skipped
    run_generator ["account", "--skip-fixture"]
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_fixture_is_skipped_if_fixture_replacement_is_given
    content = run_generator ["account", "-r", "factory_girl"]
    assert_match(/factory_girl \[not found\]/, content)
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_fixture_without_pluralization
    original_pluralize_table_name = ActiveRecord::Base.pluralize_table_names
    ActiveRecord::Base.pluralize_table_names = false
    run_generator
    assert_generated_fixture("test/fixtures/account.yml",
                             "one" => { "name" => "MyString", "age" => 1 }, "two" => { "name" => "MyString", "age" => 1 })
  ensure
    ActiveRecord::Base.pluralize_table_names = original_pluralize_table_name
  end

  def test_check_class_collision
    content = capture(:stderr) { run_generator ["object"] }
    assert_match(/The name 'Object' is either already used in your application or reserved/, content)
  end

  def test_index_is_skipped_for_belongs_to_association
    run_generator ["account", "supplier:belongs_to", "--no-indexes"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match(/index: true/, up)
      end
    end
  end

  def test_index_is_skipped_for_references_association
    run_generator ["account", "supplier:references", "--no-indexes"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match(/index: true/, up)
      end
    end
  end

  def test_add_uuid_to_create_table_migration
    run_generator ["account", "--primary_key_type=uuid"]
    assert_migration "db/migrate/create_accounts.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/create_table :accounts, id: :uuid/, change)
      end
    end
  end

  def test_database_puts_migrations_in_configured_folder
    with_database_configuration do
      run_generator ["account", "--database=secondary"]
      assert_migration "db/secondary_migrate/create_accounts.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/create_table :accounts/, change)
        end
      end
    end
  end

  def test_database_puts_migrations_in_configured_folder_with_aliases
    with_database_configuration do
      run_generator ["account", "--db=secondary"]
      assert_migration "db/secondary_migrate/create_accounts.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/create_table :accounts/, change)
        end
      end
    end
  end

  def test_polymorphic_belongs_to_generates_correct_model
    run_generator ["account", "supplier:references{polymorphic}"]

    expected_file = <<~FILE
      class Account < ApplicationRecord
        belongs_to :supplier, polymorphic: true
      end
    FILE
    assert_file "app/models/account.rb", expected_file
  end

  def test_passing_required_to_model_generator_is_deprecated
    assert_deprecated do
      run_generator ["account", "supplier:references{required}"]
    end

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.references :supplier,.*\snull: false/, up)
      end
    end
  end

  def test_null_false_is_added_for_references_by_default
    run_generator ["account", "user:references"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.references :user,.*\snull: false/, up)
      end
    end
  end

  def test_null_false_is_added_for_belongs_to_by_default
    run_generator ["account", "user:belongs_to"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.belongs_to :user,.*\snull: false/, up)
      end
    end
  end

  def test_null_false_is_not_added_when_belongs_to_required_by_default_global_config_is_false
    Rails.application.config.active_record.belongs_to_required_by_default = false

    run_generator ["account", "user:belongs_to"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.belongs_to :user/, up)
      end
    end
  end

  def test_foreign_key_is_not_added_for_non_references
    run_generator ["account", "supplier:string"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match(/foreign_key/, up)
      end
    end
  end

  def test_foreign_key_is_added_for_references
    run_generator ["account", "supplier:belongs_to", "user:references"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_match(/t\.belongs_to :supplier,.*\sforeign_key: true/, up)
        assert_match(/t\.references :user,.*\sforeign_key: true/, up)
      end
    end
  end

  def test_foreign_key_is_skipped_for_polymorphic_references
    run_generator ["account", "supplier:belongs_to{polymorphic}"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match(/foreign_key/, up)
      end
    end
  end

  def test_token_option_adds_has_secure_token
    run_generator ["user", "token:token", "auth_token:token"]
    expected_file = <<~FILE
      class User < ApplicationRecord
        has_secure_token
        has_secure_token :auth_token
      end
    FILE
    assert_file "app/models/user.rb", expected_file
  end

  def test_model_with_rich_text_attribute_adds_has_rich_text
    run_generator ["message", "content:rich_text"]
    expected_file = <<~FILE
      class Message < ApplicationRecord
        has_rich_text :content
      end
    FILE
    assert_file "app/models/message.rb", expected_file
  end

  def test_model_with_attachment_attribute_adds_has_one_attached
    run_generator ["message", "video:attachment"]
    expected_file = <<~FILE
      class Message < ApplicationRecord
        has_one_attached :video
      end
    FILE
    assert_file "app/models/message.rb", expected_file
  end

  def test_model_with_attachments_attribute_adds_has_many_attached
    run_generator ["message", "photos:attachments"]
    expected_file = <<~FILE
      class Message < ApplicationRecord
        has_many_attached :photos
      end
    FILE
    assert_file "app/models/message.rb", expected_file
  end

  def test_skip_virtual_fields_in_fixtures
    run_generator ["message", "content:rich_text", "video:attachment", "photos:attachments"]

    assert_generated_fixture("test/fixtures/messages.yml",
                             "one" => nil, "two" => nil)
  end

  private
    def assert_generated_fixture(path, parsed_contents)
      fixture_file = File.new File.expand_path(path, destination_root)
      assert_equal(parsed_contents, YAML.load(fixture_file))
    end
end
