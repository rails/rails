require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/active_record/model/model_generator'
require 'generators/rails/model/model_generator'
require 'generators/test_unit/model/model_generator'

class ModelGeneratorTest < GeneratorsTestCase

  def test_help_shows_invoked_generators_options
    content = run_generator ["--help"]
    assert_match /ActiveRecord options:/, content
    assert_match /TestUnit options:/, content
  end

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/account.rb", /class Account < ActiveRecord::Base/
  end

  def test_model_with_parent_option
    run_generator ["account", "--parent", "Admin::Account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_model_with_underscored_parent_option
    run_generator ["account", "--parent", "admin/account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_migration
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration/
  end

  def test_migration_is_skipped
    run_generator ["account", "--no-migration"]
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_migration_with_attributes
    run_generator ["product", "name:string", "supplier_id:integer"]
    assert_migration "db/migrate/create_products.rb", /t\.string :name/, /t\.integer :supplier_id/
  end

  def test_model_with_references_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier_id:references"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_model_with_belongs_to_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier_id:belongs_to"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_migration_with_timestamps
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /t.timestamps/
  end

  def test_migration_timestamps_are_skipped
    run_generator ["account", "--no-timestamps"]
    content = assert_migration "db/migrate/create_accounts.rb"
    assert_no_match /t.timestamps/, content
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/account_test.rb", /class AccountTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/accounts.yml", /name: MyString/, /age: 1/
  end

  def test_fixture_is_skipped
    run_generator ["account", "--skip-fixture"]
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_fixture_is_skipped_if_fixture_replacement_is_given
    content = run_generator ["account", "-r", "fixjour"]
    assert_match /Could not find and invoke 'fixjour'/, content
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'Object' is either already used in your application or reserved/, content
  end

  protected

    def run_generator(args=["Account", "name:string", "age:integer"])
      silence(:stdout) { Rails::Generators::ModelGenerator.start args, :root => destination_root }
    end

end
