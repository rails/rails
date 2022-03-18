# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeMigrationsTest < ActiveSupport::TestCase
      def setup
        build_app
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
      end

      test "running migrations with given scope" do
        rails "generate", "model", "user", "username:string", "password:string"

        app_file "db/migrate/01_a_migration.bukkits.rb", <<-MIGRATION
          class AMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        output = rails("db:migrate", "SCOPE=bukkits")
        assert_no_match(/create_table\(:users\)/, output)
        assert_no_match(/CreateUsers/, output)
        assert_no_match(/add_column\(:users, :email, :string\)/, output)

        assert_match(/AMigration: migrated/, output)

        # run all the migrations to test scope for down
        output = rails("db:migrate")
        assert_match(/CreateUsers: migrated/, output)

        output = rails("db:migrate", "SCOPE=bukkits", "VERSION=0")
        assert_no_match(/drop_table\(:users\)/, output)
        assert_no_match(/CreateUsers/, output)
        assert_no_match(/remove_column\(:users, :email\)/, output)

        assert_match(/AMigration: reverted/, output)

        output = rails("db:migrate", "VERSION=0")

        assert_match(/CreateUsers: reverted/, output)
      end

      test "version outputs current version" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:version")
        assert_match(/Current version: 1/, output)
      end

      test "migrate with specified VERSION in different formats" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/03_three_migration.rb", <<-MIGRATION
          class ThreeMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)
        assert_match(/up\s+003\s+Three migration/, output)

        rails "db:migrate", "VERSION=01_one_migration.rb"
        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/down\s+002\s+Two migration/, output)
        assert_match(/down\s+003\s+Three migration/, output)

        rails "db:migrate", "VERSION=3"
        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)
        assert_match(/up\s+003\s+Three migration/, output)

        rails "db:migrate", "VERSION=001"
        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/down\s+002\s+Two migration/, output)
        assert_match(/down\s+003\s+Three migration/, output)
      end

      test "migration with empty version" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails("db:migrate", "VERSION=")

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)

        output = rails("db:migrate:redo", "VERSION=", allow_failure: true)
        assert_match(/Empty VERSION provided/, output)

        output = rails("db:migrate:up", "VERSION=", allow_failure: true)
        assert_match(/VERSION is required/, output)

        output = rails("db:migrate:up", allow_failure: true)
        assert_match(/VERSION is required/, output)

        output = rails("db:migrate:down", "VERSION=", allow_failure: true)
        assert_match(/VERSION is required - To go down one migration, use db:rollback/, output)

        output = rails("db:migrate:down", allow_failure: true)
        assert_match(/VERSION is required - To go down one migration, use db:rollback/, output)

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)
      end

      test "rollback raises when VERSION is passed" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:rollback", "VERSION=01_one_migration.rb", allow_failure: true)
        assert_match(/VERSION is not supported - To rollback a specific version, use db:migrate:down/, output)
      end

      test "migration with 0 version" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)

        rails "db:migrate", "VERSION=0"

        output = rails("db:migrate:status")
        assert_match(/down\s+001\s+One migration/, output)
        assert_match(/down\s+002\s+Two migration/, output)
      end

      test "model and migration generator with change syntax" do
        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"

        output = rails("db:migrate")
        assert_match(/create_table\(:users\)/, output)
        assert_match(/CreateUsers: migrated/, output)
        assert_match(/add_column\(:users, :email, :string\)/, output)
        assert_match(/AddEmailToUsers: migrated/, output)

        output = rails("db:rollback", "STEP=2")
        assert_match(/drop_table\(:users\)/, output)
        assert_match(/CreateUsers: reverted/, output)
        assert_match(/remove_column\(:users, :email, :string\)/, output)
        assert_match(/AddEmailToUsers: reverted/, output)
      end

      test "migration status when schema migrations table is not present" do
        output = rails("db:migrate:status", allow_failure: true)
        assert_equal "Schema migrations table does not exist yet.\n", output
      end

      test "migration status" do
        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"
        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/up\s+\d{14}\s+Add email to users/, output)

        rails "db:rollback", "STEP=1"
        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/down\s+\d{14}\s+Add email to users/, output)
      end

      test "migration status without timestamps" do
        add_to_config("config.active_record.timestamped_migrations = false")

        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"
        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+\d{3,}\s+Create users/, output)
        assert_match(/up\s+\d{3,}\s+Add email to users/, output)

        rails "db:rollback", "STEP=1"
        output = rails("db:migrate:status")

        assert_match(/up\s+\d{3,}\s+Create users/, output)
        assert_match(/down\s+\d{3,}\s+Add email to users/, output)
      end

      test "migration status after rollback and redo" do
        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"
        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/up\s+\d{14}\s+Add email to users/, output)

        rails "db:rollback", "STEP=2"
        output = rails("db:migrate:status")

        assert_match(/down\s+\d{14}\s+Create users/, output)
        assert_match(/down\s+\d{14}\s+Add email to users/, output)

        rails "db:migrate:redo"
        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/up\s+\d{14}\s+Add email to users/, output)
      end

      test "migration status after rollback and forward" do
        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"
        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/up\s+\d{14}\s+Add email to users/, output)

        rails "db:rollback", "STEP=2"
        output = rails("db:migrate:status")

        assert_match(/down\s+\d{14}\s+Create users/, output)
        assert_match(/down\s+\d{14}\s+Add email to users/, output)

        rails "db:forward", "STEP=2"
        output = rails("db:migrate:status")

        assert_match(/up\s+\d{14}\s+Create users/, output)
        assert_match(/up\s+\d{14}\s+Add email to users/, output)
      end

      test "raise error on any move when current migration does not exist" do
        Dir.chdir(app_path) do
          rails "generate", "model", "user", "username:string", "password:string"
          rails "generate", "migration", "add_email_to_users", "email:string"
          rails "db:migrate"
          `rm db/migrate/*email*.rb`

          output = rails("db:migrate:status")
          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+\** NO FILE \**/, output)

          output = rails("db:rollback", allow_failure: true)
          assert_match(/rails aborted!/, output)
          assert_match(/ActiveRecord::UnknownMigrationVersionError:/, output)
          assert_match(/No migration with version number\s\d{14}\./, output)

          output = rails("db:migrate:status")
          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+\** NO FILE \**/, output)

          output = rails("db:forward", allow_failure: true)
          assert_match(/rails aborted!/, output)
          assert_match(/ActiveRecord::UnknownMigrationVersionError:/, output)
          assert_match(/No migration with version number\s\d{14}\./, output)

          output = rails("db:migrate:status")
          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+\** NO FILE \**/, output)
        end
      end

      test "raise error on any move when target migration does not exist" do
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)

        output = rails("db:migrate", "VERSION=3", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/ActiveRecord::UnknownMigrationVersionError:/, output)
        assert_match(/No migration with version number 3/, output)

        output = rails("db:migrate:status")
        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)
      end

      test "raise error on any move when VERSION has invalid format" do
        output = rails("db:migrate", "VERSION=unknown", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION=0.1.11", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION=1.1.11", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION='0 '", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION=1.", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION=1_", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate", "VERSION=1_name", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate:redo", "VERSION=unknown", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate:up", "VERSION=unknown", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)

        output = rails("db:migrate:down", "VERSION=unknown", allow_failure: true)
        assert_match(/rails aborted!/, output)
        assert_match(/Invalid format of target version/, output)
      end

      test "migration status after rollback and redo without timestamps" do
        add_to_config("config.active_record.timestamped_migrations = false")

        rails "generate", "model", "user", "username:string", "password:string"
        rails "generate", "migration", "add_email_to_users", "email:string"
        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+\d{3,}\s+Create users/, output)
        assert_match(/up\s+\d{3,}\s+Add email to users/, output)

        rails "db:rollback", "STEP=2"
        output = rails("db:migrate:status")

        assert_match(/down\s+\d{3,}\s+Create users/, output)
        assert_match(/down\s+\d{3,}\s+Add email to users/, output)

        rails "db:migrate:redo"
        output = rails("db:migrate:status")

        assert_match(/up\s+\d{3,}\s+Create users/, output)
        assert_match(/up\s+\d{3,}\s+Add email to users/, output)
      end

      test "running migrations with not timestamp head migration files" do
        app_file "db/migrate/1_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        rails "db:migrate"

        output = rails("db:migrate:status")

        assert_match(/up\s+001\s+One migration/, output)
        assert_match(/up\s+002\s+Two migration/, output)
      end

      test "schema generation when dump_schema_after_migration and schema_dump are set" do
        add_to_config("config.active_record.dump_schema_after_migration = true")

        app_file "config/database.yml", <<~EOS
          development:
            adapter: sqlite3
            database: 'dev_db'
            schema_dump: "schema_file.rb"
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          assert File.exist?("db/schema_file.rb"), "should dump schema when configured to"
        end
      end

      test "schema generation when dump_schema_after_migration is true schema_dump is false" do
        add_to_config("config.active_record.dump_schema_after_migration = true")

        app_file "config/database.yml", <<~EOS
          development:
            adapter: sqlite3
            database: 'dev_db'
            schema_dump: false
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          assert_not File.exist?("db/schema.rb"), "should not dump schema when configured not to"
        end
      end

      test "schema generation when dump_schema_after_migration is set" do
        add_to_config("config.active_record.dump_schema_after_migration = false")

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          output = rails("generate", "model", "author", "name:string")
          version = output =~ %r{[^/]+db/migrate/(\d+)_create_authors\.rb} && $1

          rails "db:migrate", "db:rollback", "db:forward"
          rails "db:migrate:up", "db:migrate:down", "VERSION=#{version}"
          assert_not File.exist?("db/schema.rb"), "should not dump schema when configured not to"
        end

        add_to_config("config.active_record.dump_schema_after_migration = true")

        Dir.chdir(app_path) do
          rails "generate", "model", "reviews", "book_id:integer"
          rails "db:migrate"

          structure_dump = File.read("db/schema.rb")
          assert_match(/create_table "reviews"/, structure_dump)
        end
      end

      test "default schema generation after migration" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          structure_dump = File.read("db/schema.rb")
          assert_match(/create_table "books"/, structure_dump)
        end
      end

      test "migration status migrated file is deleted" do
        Dir.chdir(app_path) do
          rails "generate", "model", "user", "username:string", "password:string"
          rails "generate", "migration", "add_email_to_users", "email:string"
          rails "db:migrate"
          `rm db/migrate/*email*.rb`

          output = rails("db:migrate:status")

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+\** NO FILE \**/, output)
        end
      end
    end
  end
end
