require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/active_record/model/model_generator'
require 'generators/rails/model/model_generator'
require 'generators/test_unit/model/model_generator'

class ModelGeneratorTest < GeneratorsTestCase

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/account.rb", /class Account < ActiveRecord::Base/
  end

  def test_orm_with_parent_option
    run_generator ["account", "--parent", "Admin::Account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_orm_with_underscored_parent_option
    run_generator ["account", "--parent", "admin/account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/account_test.rb", /class AccountTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/accounts.yml", /name: MyString/, /age: 1/
  end

  def test_fixtures_are_skipped
    run_generator ["account", "--skip-fixture"]
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_fixtures_are_skipped_if_fixture_replacement_is_given
    content = run_generator ["account", "-r", "fixjour"]
    assert_match /Could not find and invoke 'fixjour'/, content
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'Object' is either already used in your application or reserved/, content
  end

#  def test_model_skip_migration_skips_migration
#    run_generator('model', %w(Product name:string --skip-migration))

#    assert_generated_model_for :product
#    assert_generated_fixtures_for :products
#    assert_skipped_migration :create_products
#  end

#  def test_model_with_attributes_generates_resources_with_attributes
#    run_generator('model', %w(Product name:string supplier_id:integer created_at:timestamp))

#    assert_generated_model_for :product
#    assert_generated_fixtures_for :products
#    assert_generated_migration :create_products do |t|
#      assert_generated_column t, :name, :string
#      assert_generated_column t, :supplier_id, :integer
#      assert_generated_column t, :created_at, :timestamp
#    end
#  end

#  def test_model_with_reference_attributes_generates_belongs_to_associations
#    run_generator('model', %w(Product name:string supplier:references))

#    assert_generated_model_for :product do |body|
#      assert body =~ /^\s+belongs_to :supplier/, "#{body.inspect} should contain 'belongs_to :supplier'"
#    end
#  end

#  def test_model_with_belongs_to_attributes_generates_belongs_to_associations
#    run_generator('model', %w(Product name:string supplier:belongs_to))

#    assert_generated_model_for :product do |body|
#      assert body =~ /^\s+belongs_to :supplier/, "#{body.inspect} should contain 'belongs_to :supplier'"
#    end
#  end

  protected

    def run_generator(args=["Account", "name:string", "age:integer"])
      silence(:stdout) { Rails::Generators::ModelGenerator.start args, :root => destination_root }
    end

end
