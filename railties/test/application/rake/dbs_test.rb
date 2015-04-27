require "isolation/abstract_unit"
require "active_support/core_ext/string/strip"

module ApplicationTests
  module RakeTests
    class RakeDbsTest < ActiveSupport::TestCase
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
        ENV['DATABASE_URL'] = "sqlite3:#{database_url_db_name}"
        # ensure it's using the DATABASE_URL
        FileUtils.rm_rf("#{app_path}/config/database.yml")
      end

      def expected
        @expected ||= {}
      end

      def db_create_and_drop
        Dir.chdir(app_path) do
          output = `bundle exec rake db:create`
          assert_equal output, ""
          assert File.exist?(expected[:database])
          assert_equal expected[:database],
                        ActiveRecord::Base.connection_config[:database]
          output = `bundle exec rake db:drop`
          assert_equal output, ""
          assert !File.exist?(expected[:database])
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
          `rails generate model book title:string;
           bundle exec rake db:migrate`
          output = `bundle exec rake db:migrate:status`
          assert_match(%r{database:\s+\S*#{Regexp.escape(expected[:database])}}, output)
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
          `rails generate model book title:string;
           rake db:migrate db:schema:dump`
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
          `rails generate model book title:string;
           bundle exec rake db:migrate db:fixtures:load`
          assert_match(/#{expected[:database]}/,
                    ActiveRecord::Base.connection_config[:database])
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
          `rails generate model book title:string;
           bundle exec rake db:migrate db:structure:dump`
          structure_dump = File.read("db/structure.sql")
          assert_match(/CREATE TABLE \"books\"/, structure_dump)
          `bundle exec rake environment db:drop db:structure:load`
          assert_match(/#{expected[:database]}/,
                        ActiveRecord::Base.connection_config[:database])
          require "#{app_path}/app/models/book"
          #if structure is not loaded correctly, exception would be raised
          assert Book.count, 0
        end
      end

      test 'db:structure:dump and db:structure:load without database_url' do
        require "#{app_path}/config/environment"
        expected[:database] =  ActiveRecord::Base.configurations[Rails.env]['database']
        db_structure_dump_and_load
      end

      test 'db:structure:dump and db:structure:load with database_url' do
        require "#{app_path}/config/environment"
        set_database_url
        expected[:database] = database_url_db_name
        db_structure_dump_and_load
      end

      test 'db:structure:dump does not dump schema information when no migrations are used' do
        Dir.chdir(app_path) do
          # create table without migrations
          `bundle exec rails runner 'ActiveRecord::Base.connection.create_table(:posts) {|t| t.string :title }'`

          stderr_output = capture(:stderr) { `bundle exec rake db:structure:dump` }
          assert_empty stderr_output
          structure_dump = File.read("db/structure.sql")
          assert_match(/CREATE TABLE \"posts\"/, structure_dump)
        end
      end

      test 'db:schema:load and db:structure:load do not purge the existing database' do
        Dir.chdir(app_path) do
          `bin/rails runner 'ActiveRecord::Base.connection.create_table(:posts) {|t| t.string :title }'`

          app_file 'db/schema.rb', <<-RUBY
            ActiveRecord::Schema.define(version: 20140423102712) do
              create_table(:comments) {}
            end
          RUBY

          list_tables = lambda { `bin/rails runner 'p ActiveRecord::Base.connection.tables'`.strip }

          assert_equal '["posts"]', list_tables[]
          `bin/rake db:schema:load`
          assert_equal '["posts", "comments", "schema_migrations"]', list_tables[]

          app_file 'db/structure.sql', <<-SQL
            CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255));
          SQL

          `bin/rake db:structure:load`
          assert_equal '["posts", "comments", "schema_migrations", "users"]', list_tables[]
        end
      end

      test "db:schema:load with inflections" do
        Dir.chdir(app_path) do
          app_file 'config/initializers/inflection.rb', <<-RUBY
            ActiveSupport::Inflector.inflections do |inflect|
              inflect.irregular 'goose', 'geese'
            end
          RUBY
          app_file 'config/initializers/primary_key_table_name.rb', <<-RUBY
            ActiveRecord::Base.primary_key_prefix_type = :table_name
          RUBY
          app_file 'db/schema.rb', <<-RUBY
            ActiveRecord::Schema.define(version: 20140423102712) do
              create_table("goose".pluralize) do |t|
                t.string :name
              end
            end
          RUBY

          `bin/rake db:schema:load`

          tables = `bin/rails runner 'p ActiveRecord::Base.connection.tables'`.strip
          assert_match(/"geese"/, tables)

          columns = `bin/rails runner 'p ActiveRecord::Base.connection.columns("geese").map(&:name)'`.strip
          assert_equal columns, '["gooseid", "name"]'
        end
      end

      def db_test_load_structure
        Dir.chdir(app_path) do
          `rails generate model book title:string;
           bundle exec rake db:migrate db:structure:dump db:test:load_structure`
          ActiveRecord::Base.configurations = Rails.application.config.database_configuration
          ActiveRecord::Base.establish_connection :test
          require "#{app_path}/app/models/book"
          #if structure is not loaded correctly, exception would be raised
          assert Book.count, 0
          assert_match(/#{ActiveRecord::Base.configurations['test']['database']}/,
                        ActiveRecord::Base.connection_config[:database])
        end
      end

      test 'db:test:load_structure without database_url' do
        require "#{app_path}/config/environment"
        db_test_load_structure
      end

      test 'db:setup loads schema and seeds database' do
        begin
          @old_rails_env = ENV["RAILS_ENV"]
          @old_rack_env = ENV["RACK_ENV"]
          ENV.delete "RAILS_ENV"
          ENV.delete "RACK_ENV"

          app_file 'db/schema.rb', <<-RUBY
            ActiveRecord::Schema.define(version: "1") do
              create_table :users do |t|
                t.string :name
              end
            end
          RUBY

          app_file 'db/seeds.rb', <<-RUBY
            puts ActiveRecord::Base.connection_config[:database]
          RUBY

          Dir.chdir(app_path) do
            database_path = `bundle exec rake db:setup`
            assert_equal "development.sqlite3", File.basename(database_path.strip)
          end
        ensure
          ENV["RAILS_ENV"] = @old_rails_env
          ENV["RACK_ENV"] = @old_rack_env
        end
      end
    end
  end
end
