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

      test 'running migrations with given scope' do
        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string`

          app_file "db/migrate/01_a_migration.bukkits.rb", <<-MIGRATION
            class AMigration < ActiveRecord::Migration::Current
            end
          MIGRATION

          output = `bin/rails db:migrate SCOPE=bukkits`
          assert_no_match(/create_table\(:users\)/, output)
          assert_no_match(/CreateUsers/, output)
          assert_no_match(/add_column\(:users, :email, :string\)/, output)

          assert_match(/AMigration: migrated/, output)

          output = `bin/rails db:migrate SCOPE=bukkits VERSION=0`
          assert_no_match(/drop_table\(:users\)/, output)
          assert_no_match(/CreateUsers/, output)
          assert_no_match(/remove_column\(:users, :email\)/, output)

          assert_match(/AMigration: reverted/, output)
        end
      end

      test 'model and migration generator with change syntax' do
        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string`

           output = `bin/rails db:migrate`
           assert_match(/create_table\(:users\)/, output)
           assert_match(/CreateUsers: migrated/, output)
           assert_match(/add_column\(:users, :email, :string\)/, output)
           assert_match(/AddEmailToUsers: migrated/, output)

           output = `bin/rails db:rollback STEP=2`
           assert_match(/drop_table\(:users\)/, output)
           assert_match(/CreateUsers: reverted/, output)
           assert_match(/remove_column\(:users, :email, :string\)/, output)
           assert_match(/AddEmailToUsers: reverted/, output)
        end
      end

      test 'migration status when schema migrations table is not present' do
        output = Dir.chdir(app_path){ `bin/rails db:migrate:status 2>&1` }
        assert_equal "Schema migrations table does not exist yet.\n", output
      end

      test 'test migration status' do
        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string;
           bin/rails db:migrate`

          output = `bin/rails db:migrate:status`

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+Add email to users/, output)

          `bin/rails db:rollback STEP=1`
          output = `bin/rails db:migrate:status`

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/down\s+\d{14}\s+Add email to users/, output)
        end
      end

      test 'migration status without timestamps' do
        add_to_config('config.active_record.timestamped_migrations = false')

        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string;
           bin/rails db:migrate`

          output = `bin/rails db:migrate:status`

          assert_match(/up\s+\d{3,}\s+Create users/, output)
          assert_match(/up\s+\d{3,}\s+Add email to users/, output)

          `bin/rails db:rollback STEP=1`
          output = `bin/rails db:migrate:status`

          assert_match(/up\s+\d{3,}\s+Create users/, output)
          assert_match(/down\s+\d{3,}\s+Add email to users/, output)
        end
      end

      test 'test migration status after rollback and redo' do
        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string;
           bin/rails db:migrate`

           output = `bin/rails db:migrate:status`

           assert_match(/up\s+\d{14}\s+Create users/, output)
           assert_match(/up\s+\d{14}\s+Add email to users/, output)

           `bin/rails db:rollback STEP=2`
           output = `bin/rails db:migrate:status`

           assert_match(/down\s+\d{14}\s+Create users/, output)
           assert_match(/down\s+\d{14}\s+Add email to users/, output)

           `bin/rails db:migrate:redo`
           output = `bin/rails db:migrate:status`

           assert_match(/up\s+\d{14}\s+Create users/, output)
           assert_match(/up\s+\d{14}\s+Add email to users/, output)
        end
      end

      test 'migration status after rollback and redo without timestamps' do
        add_to_config('config.active_record.timestamped_migrations = false')

        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string;
           bin/rails db:migrate`

           output = `bin/rails db:migrate:status`

           assert_match(/up\s+\d{3,}\s+Create users/, output)
           assert_match(/up\s+\d{3,}\s+Add email to users/, output)

           `bin/rails db:rollback STEP=2`
           output = `bin/rails db:migrate:status`

           assert_match(/down\s+\d{3,}\s+Create users/, output)
           assert_match(/down\s+\d{3,}\s+Add email to users/, output)

           `bin/rails db:migrate:redo`
           output = `bin/rails db:migrate:status`

           assert_match(/up\s+\d{3,}\s+Create users/, output)
           assert_match(/up\s+\d{3,}\s+Add email to users/, output)
        end
      end

      test 'running migrations with not timestamp head migration files' do
        Dir.chdir(app_path) do

          app_file "db/migrate/1_one_migration.rb", <<-MIGRATION
            class OneMigration < ActiveRecord::Migration::Current
            end
          MIGRATION

          app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
            class TwoMigration < ActiveRecord::Migration::Current
            end
          MIGRATION

          `bin/rails db:migrate`

           output = `bin/rails db:migrate:status`

           assert_match(/up\s+001\s+One migration/, output)
           assert_match(/up\s+002\s+Two migration/, output)
        end
      end

      test 'schema generation when dump_schema_after_migration is set' do
        add_to_config('config.active_record.dump_schema_after_migration = false')

        Dir.chdir(app_path) do
          `bin/rails generate model book title:string`
          output = `bin/rails generate model author name:string`
          version = output =~ %r{[^/]+db/migrate/(\d+)_create_authors\.rb} && $1

          `bin/rails db:migrate db:rollback db:forward db:migrate:up db:migrate:down VERSION=#{version}`
          assert !File.exist?("db/schema.rb"), "should not dump schema when configured not to"
        end

        add_to_config('config.active_record.dump_schema_after_migration = true')

        Dir.chdir(app_path) do
          `bin/rails generate model reviews book_id:integer`
          `bin/rails db:migrate`

          structure_dump = File.read("db/schema.rb")
          assert_match(/create_table "reviews"/, structure_dump)
        end
      end

      test 'default schema generation after migration' do
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate`

          structure_dump = File.read("db/schema.rb")
          assert_match(/create_table "books"/, structure_dump)
        end
      end

      test 'test migration status migrated file is deleted' do
        Dir.chdir(app_path) do
          `bin/rails generate model user username:string password:string;
           bin/rails generate migration add_email_to_users email:string;
           bin/rails db:migrate
           rm db/migrate/*email*.rb`

          output = `bin/rails db:migrate:status`
          File.write('test.txt', output)

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+\** NO FILE \**/, output)
        end
      end
    end
  end
end
