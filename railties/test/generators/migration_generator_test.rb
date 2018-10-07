# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/migration/migration_generator"

class MigrationGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_migration
    migration = "change_title_body_from_posts"
    run_generator [migration]
    assert_migration "db/migrate/#{migration}.rb", /class ChangeTitleBodyFromPosts < ActiveRecord::Migration\[[0-9.]+\]/
  end

  def test_migrations_generated_simultaneously
    migrations = ["change_title_body_from_posts", "change_email_from_comments"]

    first_migration_number, second_migration_number = migrations.collect do |migration|
      run_generator [migration]
      file_name = migration_file_name "db/migrate/#{migration}.rb"

      File.basename(file_name).split("_").first
    end

    assert_not_equal first_migration_number, second_migration_number
  end

  def test_migration_with_class_name
    migration = "ChangeTitleBodyFromPosts"
    run_generator [migration]
    assert_migration "db/migrate/change_title_body_from_posts.rb", /class #{migration} < ActiveRecord::Migration\[[0-9.]+\]/
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
      assert_method :change, content do |change|
        assert_match(/add_column :posts, :title, :string/, change)
        assert_match(/add_column :posts, :body, :text/, change)
      end
    end
  end

  def test_add_migration_with_table_having_from_in_title
    migration = "add_email_address_to_excluded_from_campaign"
    run_generator [migration, "email_address:string"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :excluded_from_campaigns, :email_address, :string/, change)
      end
    end
  end

  def test_remove_migration_with_indexed_attribute
    migration = "remove_title_body_from_posts"
    run_generator [migration, "title:string:index", "body:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/remove_column :posts, :title, :string/, change)
        assert_match(/remove_column :posts, :body, :text/, change)
        assert_match(/remove_index :posts, :title/, change)
      end
    end
  end

  def test_remove_migration_with_attributes
    migration = "remove_title_body_from_posts"
    run_generator [migration, "title:string", "body:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/remove_column :posts, :title, :string/, change)
        assert_match(/remove_column :posts, :body, :text/, change)
      end
    end
  end

  def test_remove_migration_with_table_having_to_in_title
    migration = "remove_email_address_from_sent_to_user"
    run_generator [migration, "email_address:string"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/remove_column :sent_to_users, :email_address, :string/, change)
      end
    end
  end

  def test_remove_migration_with_references_options
    migration = "remove_references_from_books"
    run_generator [migration, "author:belongs_to", "distributor:references{polymorphic}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/remove_reference :books, :author/, change)
        assert_match(/remove_reference :books, :distributor, polymorphic: true/, change)
      end
    end
  end

  def test_remove_migration_with_references_removes_foreign_keys
    migration = "remove_references_from_books"
    run_generator [migration, "author:belongs_to", "distributor:references{polymorphic}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/remove_reference :books, :author,.*\sforeign_key: true/, change)
        assert_match(/remove_reference :books, :distributor/, change) # sanity check
        assert_no_match(/remove_reference :books, :distributor,.*\sforeign_key: true/, change)
      end
    end
  end

  def test_add_migration_with_attributes_and_indices
    migration = "add_title_with_index_and_body_to_posts"
    run_generator [migration, "title:string:index", "body:text", "user_id:integer:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :posts, :title, :string/, change)
        assert_match(/add_column :posts, :body, :text/, change)
        assert_match(/add_column :posts, :user_id, :integer/, change)
        assert_match(/add_index :posts, :title/, change)
        assert_match(/add_index :posts, :user_id, unique: true/, change)
      end
    end
  end

  def test_add_migration_with_attributes_and_wrong_index_declaration
    migration = "add_title_and_content_to_books"
    run_generator [migration, "title:string:inex", "content:text", "user_id:integer:unik"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :books, :title, :string/, change)
        assert_match(/add_column :books, :content, :text/, change)
        assert_match(/add_column :books, :user_id, :integer/, change)
      end
      assert_no_match(/add_index :books, :title/, content)
      assert_no_match(/add_index :books, :user_id/, content)
    end
  end

  def test_add_migration_with_attributes_without_type_and_index
    migration = "add_title_with_index_and_body_to_posts"
    run_generator [migration, "title:index", "body:text", "user_uuid:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :posts, :title, :string/, change)
        assert_match(/add_column :posts, :body, :text/, change)
        assert_match(/add_column :posts, :user_uuid, :string/, change)
        assert_match(/add_index :posts, :title/, change)
        assert_match(/add_index :posts, :user_uuid, unique: true/, change)
      end
    end
  end

  def test_add_migration_with_attributes_index_declaration_and_attribute_options
    migration = "add_title_and_content_to_books"
    run_generator [migration, "title:string{40}:index", "content:string{255}", "price:decimal{1,2}:index", "discount:decimal{3.4}:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :books, :title, :string, limit: 40/, change)
        assert_match(/add_column :books, :content, :string, limit: 255/, change)
        assert_match(/add_column :books, :price, :decimal, precision: 1, scale: 2/, change)
        assert_match(/add_column :books, :discount, :decimal, precision: 3, scale: 4/, change)
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
      assert_method :change, content do |change|
        assert_match(/add_reference :books, :author/, change)
        assert_match(/add_reference :books, :distributor, polymorphic: true/, change)
      end
    end
  end

  def test_add_migration_with_required_references
    migration = "add_references_to_books"
    run_generator [migration, "author:belongs_to{required}", "distributor:references{polymorphic,required}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_reference :books, :author, null: false/, change)
        assert_match(/add_reference :books, :distributor, polymorphic: true, null: false/, change)
      end
    end
  end

  def test_add_migration_with_references_adds_foreign_keys
    migration = "add_references_to_books"
    run_generator [migration, "author:belongs_to", "distributor:references{polymorphic}"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_reference :books, :author,.*\sforeign_key: true/, change)
        assert_match(/add_reference :books, :distributor/, change) # sanity check
        assert_no_match(/add_reference :books, :distributor,.*\sforeign_key: true/, change)
      end
    end
  end

  def test_create_join_table_migration
    migration = "add_media_join_table"
    run_generator [migration, "artist_id", "musics:uniq"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/create_join_table :artists, :musics/, change)
        assert_match(/# t\.index \[:artist_id, :music_id\]/, change)
        assert_match(/  t\.index \[:music_id, :artist_id\], unique: true/, change)
      end
    end
  end

  def test_create_table_migration
    run_generator ["create_books", "title:string", "content:text"]
    assert_migration "db/migrate/create_books.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/create_table :books/, change)
        assert_match(/  t\.string :title/, change)
        assert_match(/  t\.text :content/, change)
      end
    end
  end

  def test_add_uuid_to_create_table_migration
    run_generator ["create_books", "--primary_key_type=uuid"]
    assert_migration "db/migrate/create_books.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/create_table :books, id: :uuid/, change)
      end
    end
  end

  def test_database_puts_migrations_in_configured_folder
    with_secondary_database_configuration do
      run_generator ["create_books", "--database=secondary"]
      assert_migration "db/secondary_migrate/create_books.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/create_table :books/, change)
        end
      end
    end
  end

  def test_should_create_empty_migrations_if_name_not_start_with_add_or_remove_or_create
    migration = "delete_books"
    run_generator [migration, "title:string", "content:text"]

    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/^\s*$/, change)
      end
    end
  end

  def test_properly_identifies_usage_file
    assert generator_class.send(:usage_path)
  end

  def test_migration_with_singular_table_name
    with_singular_table_name do
      migration = "add_title_body_to_post"
      run_generator [migration, "title:string"]
      assert_migration "db/migrate/#{migration}.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/add_column :post, :title, :string/, change)
        end
      end
    end
  end

  def test_create_join_table_migration_with_singular_table_name
    with_singular_table_name do
      migration = "add_media_join_table"
      run_generator [migration, "artist_id", "music:uniq"]

      assert_migration "db/migrate/#{migration}.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/create_join_table :artist, :music/, change)
          assert_match(/# t\.index \[:artist_id, :music_id\]/, change)
          assert_match(/  t\.index \[:music_id, :artist_id\], unique: true/, change)
        end
      end
    end
  end

  def test_create_table_migration_with_singular_table_name
    with_singular_table_name do
      run_generator ["create_book", "title:string", "content:text"]
      assert_migration "db/migrate/create_book.rb" do |content|
        assert_method :change, content do |change|
          assert_match(/create_table :book/, change)
          assert_match(/  t\.string :title/, change)
          assert_match(/  t\.text :content/, change)
        end
      end
    end
  end

  def test_create_table_migration_with_token_option
    run_generator ["create_users", "token:token", "auth_token:token"]
    assert_migration "db/migrate/create_users.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/create_table :users/, change)
        assert_match(/  t\.string :token/, change)
        assert_match(/  t\.string :auth_token/, change)
        assert_match(/add_index :users, :token, unique: true/, change)
        assert_match(/add_index :users, :auth_token, unique: true/, change)
      end
    end
  end

  def test_add_migration_with_token_option
    migration = "add_token_to_users"
    run_generator [migration, "auth_token:token"]
    assert_migration "db/migrate/#{migration}.rb" do |content|
      assert_method :change, content do |change|
        assert_match(/add_column :users, :auth_token, :string/, change)
        assert_match(/add_index :users, :auth_token, unique: true/, change)
      end
    end
  end

  def test_add_migration_to_configured_path
    old_paths = Rails.application.config.paths["db/migrate"]
    Rails.application.config.paths.add "db/migrate", with: "db2/migrate"

    migration = "migration_in_custom_path"
    run_generator [migration]
    assert_migration "db2/migrate/#{migration}.rb", /.*/
  ensure
    Rails.application.config.paths["db/migrate"] = old_paths
  end

  private

    def with_singular_table_name
      old_state = ActiveRecord::Base.pluralize_table_names
      ActiveRecord::Base.pluralize_table_names = false
      yield
    ensure
      ActiveRecord::Base.pluralize_table_names = old_state
    end
end
