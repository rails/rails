require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeMigrationsTest < ActiveSupport::TestCase
      def setup
        build_app
        boot_rails
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
      end

      test 'running migrations with given scope' do
        Dir.chdir(app_path) do
          `rails generate model user username:string password:string`

          app_file "db/migrate/01_a_migration.bukkits.rb", <<-MIGRATION
            class AMigration < ActiveRecord::Migration
            end
          MIGRATION

          output = `rake db:migrate SCOPE=bukkits`
          assert_no_match(/create_table\(:users\)/, output)
          assert_no_match(/CreateUsers/, output)
          assert_no_match(/add_column\(:users, :email, :string\)/, output)

          assert_match(/AMigration: migrated/, output)

          output = `rake db:migrate SCOPE=bukkits VERSION=0`
          assert_no_match(/drop_table\(:users\)/, output)
          assert_no_match(/CreateUsers/, output)
          assert_no_match(/remove_column\(:users, :email\)/, output)

          assert_match(/AMigration: reverted/, output)
        end
      end

      test 'model and migration generator with change syntax' do
        Dir.chdir(app_path) do
          `rails generate model user username:string password:string;
           rails generate migration add_email_to_users email:string`

           output = `rake db:migrate`
           assert_match(/create_table\(:users\)/, output)
           assert_match(/CreateUsers: migrated/, output)
           assert_match(/add_column\(:users, :email, :string\)/, output)
           assert_match(/AddEmailToUsers: migrated/, output)

           output = `rake db:rollback STEP=2`
           assert_match(/drop_table\(:users\)/, output)
           assert_match(/CreateUsers: reverted/, output)
           assert_match(/remove_column\(:users, :email, :string\)/, output)
           assert_match(/AddEmailToUsers: reverted/, output)
        end
      end

      test 'migration status when schema migrations table is not present' do
        output = Dir.chdir(app_path){ `rake db:migrate:status` }
        assert_equal "Schema migrations table does not exist yet.\n", output
      end

      test 'test migration status' do
        Dir.chdir(app_path) do
          `rails generate model user username:string password:string;
           rails generate migration add_email_to_users email:string;
           rake db:migrate`

          output = `rake db:migrate:status`

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/up\s+\d{14}\s+Add email to users/, output)

          `rake db:rollback STEP=1`
          output = `rake db:migrate:status`

          assert_match(/up\s+\d{14}\s+Create users/, output)
          assert_match(/down\s+\d{14}\s+Add email to users/, output)
        end
      end

      test 'migration status without timestamps' do
        add_to_config('config.active_record.timestamped_migrations = false')

        Dir.chdir(app_path) do
          `rails generate model user username:string password:string;
           rails generate migration add_email_to_users email:string;
           rake db:migrate`

          output = `rake db:migrate:status`

          assert_match(/up\s+\d{3,}\s+Create users/, output)
          assert_match(/up\s+\d{3,}\s+Add email to users/, output)

          `rake db:rollback STEP=1`
          output = `rake db:migrate:status`

          assert_match(/up\s+\d{3,}\s+Create users/, output)
          assert_match(/down\s+\d{3,}\s+Add email to users/, output)
        end
      end

      test 'test migration status after rollback and redo' do
        Dir.chdir(app_path) do
          `rails generate model user username:string password:string;
           rails generate migration add_email_to_users email:string;
           rake db:migrate`

           output = `rake db:migrate:status`

           assert_match(/up\s+\d{14}\s+Create users/, output)
           assert_match(/up\s+\d{14}\s+Add email to users/, output)

           `rake db:rollback STEP=2`
           output = `rake db:migrate:status`

           assert_match(/down\s+\d{14}\s+Create users/, output)
           assert_match(/down\s+\d{14}\s+Add email to users/, output)

           `rake db:migrate:redo`
           output = `rake db:migrate:status`

           assert_match(/up\s+\d{14}\s+Create users/, output)
           assert_match(/up\s+\d{14}\s+Add email to users/, output)
        end
      end

      test 'migration to add timestamps to products'  do
        Dir.chdir(app_path) do
          `rails generate migration create_products name:string;
           rails generate migration add_timestamps_to_products`

           output = `rake db:migrate`
           assert_match(/create_table\(:products\)/, output)
           assert_match(/CreateProducts: migrated/, output)
           assert_match(/add_timestamps\(:products\)/, output)
           assert_match(/AddTimestampsToProducts: migrated/, output)

           output = `rake db:rollback STEP=2`
           assert_match(/drop_table\(:products\)/, output)
           assert_match(/CreateProducts: reverted/, output)
           assert_match(/remove_timestamps\(:products\)/, output)
           assert_match(/AddTimestampsToProducts: reverted/, output)
        end
      end

      test 'migration to remove timestamps from products'  do
        Dir.chdir(app_path) do
          `rails generate migration create_products name:string;
           rails generate migration remove_timestamps_from_products`

           output = `rake db:migrate`
           assert_match(/create_table\(:products\)/, output)
           assert_match(/CreateProducts: migrated/, output)
           assert_match(/remove_timestamps\(:products\)/, output)
           assert_match(/RemoveTimestampsFromProducts: migrated/, output)

           output = `rake db:rollback STEP=2`
           assert_match(/drop_table\(:products\)/, output)
           assert_match(/CreateProducts: reverted/, output)
           assert_match(/add_timestamps\(:products\)/, output)
           assert_match(/RemoveTimestampsFromProducts: reverted/, output)
        end
      end

      test 'migration status after rollback and redo without timestamps' do
        add_to_config('config.active_record.timestamped_migrations = false')

        Dir.chdir(app_path) do
          `rails generate model user username:string password:string;
           rails generate migration add_email_to_users email:string;
           rake db:migrate`

           output = `rake db:migrate:status`

           assert_match(/up\s+\d{3,}\s+Create users/, output)
           assert_match(/up\s+\d{3,}\s+Add email to users/, output)

           `rake db:rollback STEP=2`
           output = `rake db:migrate:status`

           assert_match(/down\s+\d{3,}\s+Create users/, output)
           assert_match(/down\s+\d{3,}\s+Add email to users/, output)

           `rake db:migrate:redo`
           output = `rake db:migrate:status`

           assert_match(/up\s+\d{3,}\s+Create users/, output)
           assert_match(/up\s+\d{3,}\s+Add email to users/, output)
        end
      end
    end
  end
end
