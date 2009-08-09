require 'generators/generator_test_helper'

class RailsModelGeneratorTest < GeneratorTestCase

  def test_model_generates_resources
    run_generator('model', %w(Product name:string))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_migration :create_products
  end

  def test_model_skip_migration_skips_migration
    run_generator('model', %w(Product name:string --skip-migration))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_skipped_migration :create_products
  end

  def test_model_with_attributes_generates_resources_with_attributes
    run_generator('model', %w(Product name:string supplier_id:integer created_at:timestamp))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_migration :create_products do |t|
      assert_generated_column t, :name, :string
      assert_generated_column t, :supplier_id, :integer
      assert_generated_column t, :created_at, :timestamp
    end
  end

  def test_model_with_reference_attributes_generates_belongs_to_associations
    run_generator('model', %w(Product name:string supplier:references))

    assert_generated_model_for :product do |body|
      assert body =~ /^\s+belongs_to :supplier/, "#{body.inspect} should contain 'belongs_to :supplier'"
    end
  end

  def test_model_with_belongs_to_attributes_generates_belongs_to_associations
    run_generator('model', %w(Product name:string supplier:belongs_to))

    assert_generated_model_for :product do |body|
      assert body =~ /^\s+belongs_to :supplier/, "#{body.inspect} should contain 'belongs_to :supplier'"
    end
  end

  def test_migration_with_namespace
    run_generator('model', %w(Gallery::Image))
    assert_generated_migration :gallery_images
    assert_skipped_migration :create_images
  end

  def test_migration_with_nested_namespace
    run_generator('model', %w(Admin::Gallery::Image))
    assert_skipped_migration :create_images
    assert_skipped_migration :create_gallery_images

    assert_generated_migration :admin_gallery_images do |t|
      assert_generated_table t, :admin_gallery_images
    end
  end

  def test_migration_with_nested_namespace_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator('model', %w(Admin::Gallery::Image))
    assert_skipped_migration :create_images
    assert_skipped_migration :create_gallery_images
    assert_skipped_migration :create_admin_gallery_images
    assert_generated_migration :admin_gallery_image do |t|
      assert_generated_table t, :admin_gallery_image
    end
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end
  
  def test_migration_with_namespaces_in_model_name_without_plurization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator('model', %w(Gallery::Image))
    assert_generated_migration :create_gallery_image
    assert_skipped_migration :create_gallery_images
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator('model', %w(Account))
    assert_generated_migration :create_account
    assert_skipped_migration :create_accounts
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

end
