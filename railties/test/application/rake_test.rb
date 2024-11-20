# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  class RakeTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_gems_tasks_are_loaded_first_than_application_ones
      app_file "lib/tasks/app.rake", <<-RUBY
        $task_loaded = Rake::Task.task_defined?("db:create:all")
      RUBY

      require "#{app_path}/config/environment"
      ::Rails.application.load_tasks
      assert $task_loaded
    end

    test "framework tasks are evaluated only once" do
      assert_equal ["Rails version"], rails("about").scan(/^Rails version/)
    end

    test "tasks can invoke framework tasks via Rails::Command.invoke" do
      add_to_config <<~RUBY
        rake_tasks do
          task :invoke_about do
            Rails::Command.invoke :about
          end
        end
      RUBY

      assert_match(/^Rails version/, rails("invoke_about"))
    end

    test "help arguments describe rake tasks" do
      task_description = <<~DESC
          rails db:migrate
              Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog).
      DESC

      assert_match task_description, rails("db:migrate", "-h")
    end

    test "task backtrace is silenced" do
      add_to_config <<-RUBY
        rake_tasks do
          task :boom do
            raise "boom"
          end
        end
      RUBY

      backtrace = rails("boom", allow_failure: true).lines.grep(/:\d+:in /)
      app_lines, framework_lines = backtrace.partition { |line| line.start_with?(app_path) }

      assert_not_empty app_lines
      assert_empty framework_lines
    end

    test "task is protected when previous migration was production" do
      with_rails_env "production" do
        rails "generate", "model", "product", "name:string"
        rails "db:create", "db:migrate"
        output = rails("db:test:prepare", allow_failure: true)

        assert_match(/ActiveRecord::ProtectedEnvironmentError/, output)
      end
    end

    def test_not_protected_when_previous_migration_was_not_production
      with_rails_env "test" do
        rails "generate", "model", "product", "name:string"
        rails "db:create", "db:migrate"
        output = rails("db:test:prepare", "test")

        assert_no_match(/ActiveRecord::ProtectedEnvironmentError/, output)
      end
    end

    def test_environment_is_required_in_rake_tasks
      app_file "config/environment.rb", <<-RUBY
        SuperMiddleware = Struct.new(:app)

        Rails.application.configure do
          config.middleware.use SuperMiddleware
        end

        Rails.application.initialize!
      RUBY

      assert_match("SuperMiddleware", rails("middleware"))
    end

    def test_initializers_are_executed_in_rake_tasks
      add_to_config <<-RUBY
        initializer "do_something" do
          puts "Doing something..."
        end

        rake_tasks do
          task do_nothing: :environment do
          end
        end
      RUBY

      output = rails("do_nothing")
      assert_match "Doing something...", output
    end

    def test_does_not_explode_when_accessing_a_model
      add_to_config <<-RUBY
        rake_tasks do
          task do_nothing: :environment do
            Hello.new.world
          end
        end
      RUBY

      app_file "app/models/hello.rb", <<-RUBY
        class Hello
          def world
            puts 'Hello world'
          end
        end
      RUBY

      output = rails("do_nothing")
      assert_match "Hello world", output
    end

    def test_should_not_eager_load_model_for_rake_when_rake_eager_load_is_false
      add_to_config <<-RUBY
        rake_tasks do
          task do_nothing: :environment do
            puts 'There is nothing'
          end
        end
      RUBY

      add_to_env_config "production", <<-RUBY
        config.eager_load = true
      RUBY

      app_file "app/models/hello.rb", <<-RUBY
        raise 'should not be pre-required for rake even eager_load=true'
      RUBY

      output = rails("do_nothing", "RAILS_ENV=production")
      assert_match "There is nothing", output
    end

    def test_should_eager_load_model_for_rake_when_rake_eager_load_is_true
      add_to_config <<-RUBY
        rake_tasks do
          task do_something: :environment do
            puts "Answer: " + Hello::TEST.to_s
          end
        end
      RUBY

      add_to_env_config "production", <<-RUBY
        config.rake_eager_load = true
      RUBY

      app_file "app/models/hello.rb", <<-RUBY
        class Hello
          TEST = 42
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails do_something RAILS_ENV=production` }
      assert_equal "Answer: 42\n", output.lines.last
    end

    def test_code_statistics
      assert_match(/Code LOC: \d+\s+Test LOC: \d+\s+ Code to Test Ratio: 1:\w+/, rails("stats"))
    end

    def test_loading_specific_fixtures
      rails "generate", "model", "user", "username:string", "password:string"
      rails "generate", "model", "product", "name:string"
      rails "db:migrate"

      require "#{rails_root}/config/environment"

      # loading a specific fixture
      rails "db:fixtures:load", "FIXTURES=products"

      assert_equal 2, Product.count
      assert_equal 0, User.count
    end

    def test_loading_only_yml_fixtures
      rails "db:migrate"

      app_file "test/fixtures/products.csv", ""

      require "#{rails_root}/config/environment"
      assert_nothing_raised do
        rails "db:fixtures:load"
      end
    end

    def test_scaffold_tests_pass_by_default
      rails "generate", "scaffold", "user", "username:string", "password:string"
      with_rails_env("test") do
        rails("db:migrate")
      end
      output = rails("test")

      assert_match(/7 runs, 11 assertions, 0 failures, 0 errors/, output)
      assert_no_match(/Errors running/, output)
    end

    def test_api_scaffold_tests_pass_by_default
      add_to_config <<-RUBY
        config.api_only = true
      RUBY

      app_file "app/controllers/application_controller.rb", <<-RUBY
        class ApplicationController < ActionController::API
        end
      RUBY

      rails "generate", "scaffold", "user", "username:string", "password:string"
      with_rails_env("test") { rails("db:migrate") }
      output = rails("test")

      assert_match(/5 runs, 9 assertions, 0 failures, 0 errors/, output)
      assert_no_match(/Errors running/, output)
    end

    def test_scaffold_with_references_columns_tests_pass_by_default
      rails "generate", "model", "Product"
      rails "generate", "model", "Cart"
      rails "generate", "scaffold", "LineItems", "product:references", "cart:belongs_to"
      with_rails_env("test") do
        rails("db:migrate")
      end
      output = rails("test")

      assert_match(/7 runs, 11 assertions, 0 failures, 0 errors/, output)
      assert_no_match(/Errors running/, output)
    end

    def test_db_test_prepare_when_using_sql_format
      add_to_config "config.active_record.schema_format = :sql"
      rails "generate", "scaffold", "user", "username:string"
      rails "db:migrate"
      output = rails("db:test:prepare", "--trace")
      assert_match(/Execute db:test:load_schema/, output)
    end

    def test_rake_dump_structure_should_be_called_twice_when_migrate_redo
      add_to_config "config.active_record.schema_format = :sql"

      rails "g", "model", "post", "title:string"
      output = rails("db:migrate:redo", "--trace")

      # expect only Invoke db:structure:dump (first_time)
      assert_no_match(/^\*\* Invoke db:structure:dump\s+$/, output)
    end

    def test_rake_dump_schema_cache
      rails "generate", "model", "post", "title:string"
      rails "generate", "model", "product", "name:string"
      rails "db:migrate", "db:schema:cache:dump"
      assert File.exist?(File.join(app_path, "db", "schema_cache.yml"))
    end

    def test_rake_clear_schema_cache
      rails "db:schema:cache:dump", "db:schema:cache:clear"
      assert_not File.exist?(File.join(app_path, "db", "schema_cache.yml"))
    end

    def test_copy_templates
      rails "app:templates:copy"
      %w(controller mailer scaffold).each do |dir|
        assert File.exist?(File.join(app_path, "lib", "templates", "erb", dir))
      end
      %w(controller helper scaffold_controller).each do |dir|
        assert File.exist?(File.join(app_path, "lib", "templates", "rails", dir))
      end
    end

    def test_template_load_initializers
      app_file "config/initializers/dummy.rb", "puts 'Hello, World!'"
      app_file "template.rb", ""

      output = rails("app:template", "LOCATION=template.rb")
      assert_match(/Hello, World!/, output)
    end
  end
end
