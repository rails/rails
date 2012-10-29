require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeDbsTest < Test::Unit::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        boot_rails
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
      end

      def database_url_db_name
        "db/database_url_db.sqlite3"
      end

      def set_database_url
        ENV['DATABASE_URL'] = "sqlite3://:@localhost/#{database_url_db_name}"
      end

      def expected
        @expected ||= {}
      end

      def db_create_and_drop
        Dir.chdir(app_path) do
          output = `bundle exec rake db:create`
          assert_equal output, ""
          assert File.exists?(expected[:database])
          assert_equal expected[:database],
                        ActiveRecord::Base.connection_config[:database]
          output = `bundle exec rake db:drop`
          assert_equal output, ""
          assert !File.exists?(expected[:database])
        end
      end

      test 'db:create and db:drop without database url' do
        require "#{app_path}/config/environment"
        expected[:database] = ActiveRecord::Base.configurations[Rails.env]['database']
        db_create_and_drop
      end

      test 'db:create and db:drop with database url' do
        require "#{app_path}/config/environment"
        set_database_url
        expected[:database] = database_url_db_name
        db_create_and_drop
      end

      def db_migrate_and_status
        Dir.chdir(app_path) do
          `rails generate model book title:string`
          `bundle exec rake db:migrate`
          output = `bundle exec rake db:migrate:status`
          assert_match(/database:\s+\S*#{expected[:database]}/, output)
          assert_match(/up\s+\d{14}\s+Create books/, output)
        end
      end

      test 'db:migrate and db:migrate:status without database_url' do
        require "#{app_path}/config/environment"
        expected[:database] = ActiveRecord::Base.configurations[Rails.env]['database']
        db_migrate_and_status
      end

      test 'db:migrate and db:migrate:status with database_url' do
        require "#{app_path}/config/environment"
        set_database_url
        expected[:database] = database_url_db_name
        db_migrate_and_status
      end

      def db_schema_dump
        Dir.chdir(app_path) do
          `rails generate model book title:string`
          `rake db:migrate`
          `rake db:schema:dump`

          assert File.exists?("db/schema.rb"), "db/schema.rb doesn't exist"

          schema_dump = File.read("db/schema.rb")

          assert_match(/create_table \"books\"/, schema_dump)
        end
      end

      test 'db:schema:dump without database_url' do
        db_schema_dump
      end

      test 'db:schema:dump with database_url' do
        set_database_url
        db_schema_dump
      end

      def db_fixtures_load
        Dir.chdir(app_path) do
          `rails generate model book title:string`
          `bundle exec rake db:migrate`
          `bundle exec rake db:fixtures:load`
          assert_match /#{expected[:database]}/,
                    ActiveRecord::Base.connection_config[:database]
          require "#{app_path}/app/models/book"
          assert_equal 2, Book.count
        end
      end

      test 'db:fixtures:load without database_url' do
        require "#{app_path}/config/environment"
        expected[:database] =  ActiveRecord::Base.configurations[Rails.env]['database']
        db_fixtures_load
      end

      test 'db:fixtures:load with database_url' do
        require "#{app_path}/config/environment"
        set_database_url
        expected[:database] = database_url_db_name
        db_fixtures_load
      end

      def db_structure_dump_and_load
        Dir.chdir(app_path) do
          `rails generate model book title:string`
          `bundle exec rake db:create`
          `bundle exec rake db:migrate`
          `bundle exec rake db:structure:dump`

          assert File.exists?("db/structure.sql"), "db/structure.sql doesn't exist"

          structure_dump = File.read("db/structure.sql")

          assert_match /CREATE TABLE \"books\"/, structure_dump

          `bundle exec rake db:drop`
          `bundle exec rake db:structure:load`

          assert_match /#{expected[:database]}/,
                       ActiveRecord::Base.connection_config[:database]

          require "#{app_path}/app/models/book"
          #if structure is not loaded correctly, exception would be raised
          assert_equal Book.count, 0
        end
      end

      test 'db:structure:dump and db:structure:load without database_url' do
        require "#{app_path}/config/environment"
        expected[:database] = ActiveRecord::Base.configurations[Rails.env]['database']
        db_structure_dump_and_load
      end

      test 'db:structure:dump and db:structure:load with database_url' do
        require "#{app_path}/config/environment"
        set_database_url
        expected[:database] = database_url_db_name
        db_structure_dump_and_load
      end

      def db_test_load_structure
        Dir.chdir(app_path) do
          `rails generate model book title:string`
          `bundle exec rake db:migrate`
          `bundle exec rake db:structure:dump`
          `bundle exec rake db:test:load_structure`
          ActiveRecord::Base.configurations = Rails.application.config.database_configuration
          ActiveRecord::Base.establish_connection 'test'
          require "#{app_path}/app/models/book"

          #if structure is not loaded correctly, exception would be raised
          assert_equal Book.count, 0
          assert_match /#{ActiveRecord::Base.configurations['test']['database']}/,
                       ActiveRecord::Base.connection_config[:database]
        end
      end

      test 'db:test:load_structure without database_url' do
        require "#{app_path}/config/environment"
        db_test_load_structure
      end

      test 'db:test:load_structure with database_url' do
        require "#{app_path}/config/environment"
        set_database_url
        db_test_load_structure
      end
    end
  end
end
