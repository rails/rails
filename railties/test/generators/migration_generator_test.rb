require 'generators/generators_test_helper'
require 'rails/generators/rails/migration/migration_generator'

class MigrationGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_migration
    migration = "change_title_body_from_posts"
    run_generator [migration]
    assert_migration "db/migrate/#{migration}.rb", /class ChangeTitleBodyFromPosts < ActiveRecord::Migration/
  end

  def test_migrations_generated_simultaneously
    migrations = ["change_title_body_from_posts", "change_email_from_comments"]

    first_migration_number, second_migration_number = migrations.collect do |migration|
      run_generator [migration]
      file_name = migration_file_name "db/migrate/#{migration}.rb"

      File.basename(file_name).split('_').first
    end

    assert_not_equal first_migration_number, second_migration_number
  end

  def test_migration_with_class_name
    migration = "ChangeTitleBodyFromPosts"
    run_generator [migration]
    assert_migration "db/migrate/change_title_body_from_posts.rb", /class #{migration} < ActiveRecord::Migration/
  end

  def test_add_migration_with_attributes
    migration = "add_title_body_to_posts"
    run_generator [migration, "title:string", "body:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_column :posts, :title, :string/, up)
        assert_match(/add_column :posts, :body, :text/, up)
      end
    end
  end

  def test_remove_migration_with_attributes
    migration = "remove_title_body_from_posts"
    run_generator [migration, "title:string", "body:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :up, content do |up|
        assert_match(/remove_column :posts, :title/, up)
        assert_match(/remove_column :posts, :body/, up)
      end

      assert_method :down, content do |down|
        assert_match(/add_column :posts, :title, :string/, down)
        assert_match(/add_column :posts, :body, :text/, down)
      end
    end
  end

  def test_should_create_empty_migrations_if_name_not_start_with_add_or_remove
    migration = "create_books"
    run_generator [migration, "title:string", "content:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :up, content do |up|
        assert_match(/^\s*$/, up)
      end

      assert_method :down, content do |down|
        assert_match(/^\s*$/, down)
      end
    end
  end
end
