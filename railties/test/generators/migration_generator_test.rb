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
  
  def test_migration_with_invalid_file_name
    migration = "add_something:datetime"
    assert_raise ActiveRecord::IllegalMigrationNameError do
      run_generator [migration]
    end
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

  def test_remove_migration_with_indexed_attribute
    migration = "remove_title_body_from_posts"
    run_generator [migration, "title:string:index", "body:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :up, content do |up|
        assert_match(/remove_column :posts, :title/, up)
        assert_match(/remove_column :posts, :body/, up)
      end

      assert_method :down, content do |down|
        assert_match(/add_column :posts, :title, :string/, down)
        assert_match(/add_column :posts, :body, :text/, down)
        assert_match(/add_index :posts, :title/, down)
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

  def test_remove_migration_with_references_options
    migration = "remove_references_from_books"
    run_generator [migration, "author:belongs_to", "distributor:references{polymorphic}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :up, content do |up|
        assert_match(/remove_reference :books, :author/, up)
        assert_match(/remove_reference :books, :distributor, polymorphic: true/, up)
      end

      assert_method :down, content do |down|
        assert_match(/add_reference :books, :author, index: true/, down)
        assert_match(/add_reference :books, :distributor, polymorphic: true, index: true/, down)
      end
    end
  end

  def test_add_migration_with_attributes_and_indices
    migration = "add_title_with_index_and_body_to_posts"
    run_generator [migration, "title:string:index", "body:text", "user_id:integer:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_column :posts, :title, :string/, up)
        assert_match(/add_column :posts, :body, :text/, up)
        assert_match(/add_column :posts, :user_id, :integer/, up)
      end
      assert_match(/add_index :posts, :title/, content)
      assert_match(/add_index :posts, :user_id, unique: true/, content)
    end
  end

  def test_add_migration_with_attributes_and_wrong_index_declaration
    migration = "add_title_and_content_to_books"
    run_generator [migration, "title:string:inex", "content:text", "user_id:integer:unik"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_column :books, :title, :string/, up)
        assert_match(/add_column :books, :content, :text/, up)
        assert_match(/add_column :books, :user_id, :integer/, up)
      end
      assert_no_match(/add_index :books, :title/, content)
      assert_no_match(/add_index :books, :user_id/, content)
    end
  end

  def test_add_migration_with_attributes_without_type_and_index
    migration = "add_title_with_index_and_body_to_posts"
    run_generator [migration, "title:index", "body:text", "user_uuid:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_column :posts, :title, :string/, up)
        assert_match(/add_column :posts, :body, :text/, up)
        assert_match(/add_column :posts, :user_uuid, :string/, up)
      end
      assert_match(/add_index :posts, :title/, content)
      assert_match(/add_index :posts, :user_uuid, unique: true/, content)
    end
  end

  def test_add_migration_with_attributes_index_declaration_and_attribute_options
    migration = "add_title_and_content_to_books"
    run_generator [migration, "title:string{40}:index", "content:string{255}", "price:decimal{1,2}:index", "discount:decimal{3.4}:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_column :books, :title, :string, limit: 40/, up)
        assert_match(/add_column :books, :content, :string, limit: 255/, up)
        assert_match(/add_column :books, :price, :decimal, precision: 1, scale: 2/, up)
        assert_match(/add_column :books, :discount, :decimal, precision: 3, scale: 4/, up)
      end
      assert_match(/add_index :books, :title/, content)
      assert_match(/add_index :books, :price/, content)
      assert_match(/add_index :books, :discount, unique: true/, content)
    end
  end

  def test_add_migration_with_references_options
    migration = "add_references_to_books"
    run_generator [migration, "author:belongs_to", "distributor:references{polymorphic}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/add_reference :books, :author, index: true/, up)
        assert_match(/add_reference :books, :distributor, polymorphic: true, index: true/, up)
      end
    end
  end

  def test_create_join_table_migration
    migration = "add_media_join_table"
    run_generator [migration, "artist_id", "musics:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |up|
        assert_match(/create_join_table :artists, :musics/, up)
        assert_match(/# t.index \[:artist_id, :music_id\]/, up)
        assert_match(/  t.index \[:music_id, :artist_id\], unique: true/, up)
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

  def test_properly_identifies_usage_file
    assert generator_class.send(:usage_path)
  end
end
