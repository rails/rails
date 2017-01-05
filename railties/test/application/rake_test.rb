require "isolation/abstract_unit"
require "active_support/core_ext/string/strip"

module ApplicationTests
  class RakeTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

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

    test "task is protected when previous migration was production" do
      Dir.chdir(app_path) do
        output = `bin/rails generate model product name:string;
         env RAILS_ENV=production bin/rails db:create db:migrate;
         env RAILS_ENV=production bin/rails db:test:prepare test 2>&1`

        assert_match(/ActiveRecord::ProtectedEnvironmentError/, output)
      end
    end

    def test_not_protected_when_previous_migration_was_not_production
      Dir.chdir(app_path) do
        output = `bin/rails generate model product name:string;
         env RAILS_ENV=test bin/rails db:create db:migrate;
         env RAILS_ENV=test bin/rails db:test:prepare test 2>&1`

        refute_match(/ActiveRecord::ProtectedEnvironmentError/, output)
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

      assert_match("SuperMiddleware", Dir.chdir(app_path) { `bin/rails middleware` })
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

      output = Dir.chdir(app_path) { `bin/rails do_nothing` }
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

      output = Dir.chdir(app_path) { `bin/rails do_nothing` }
      assert_match "Hello world", output
    end

    def test_should_not_eager_load_model_for_rake
      add_to_config <<-RUBY
        rake_tasks do
          task do_nothing: :environment do
          end
        end
      RUBY

      add_to_env_config "production", <<-RUBY
        config.eager_load = true
      RUBY

      app_file "app/models/hello.rb", <<-RUBY
        raise 'should not be pre-required for rake even eager_load=true'
      RUBY

      Dir.chdir(app_path) do
        assert system("bin/rails do_nothing RAILS_ENV=production"),
               "should not be pre-required for rake even eager_load=true"
      end
    end

    def test_code_statistics_sanity
      assert_match "Code LOC: 26     Test LOC: 0     Code to Test Ratio: 1:0.0",
        Dir.chdir(app_path) { `bin/rails stats` }
    end

    def test_rails_routes_calls_the_route_inspector
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails routes` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output
    end

    def test_singular_resource_output_in_rake_routes
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          resource :post
        end
      RUBY

      expected_output = ["   Prefix Verb   URI Pattern          Controller#Action",
                         " new_post GET    /post/new(.:format)  posts#new",
                         "edit_post GET    /post/edit(.:format) posts#edit",
                         "     post GET    /post(.:format)      posts#show",
                         "          PATCH  /post(.:format)      posts#update",
                         "          PUT    /post(.:format)      posts#update",
                         "          DELETE /post(.:format)      posts#destroy",
                         "          POST   /post(.:format)      posts#create\n"].join("\n")

      output = Dir.chdir(app_path) { `bin/rails routes -c PostController` }
      assert_equal expected_output, output
    end

    def test_rails_routes_with_global_search_key
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
          post '/cart', to: 'cart#create'
          get '/basketballs', to: 'basketball#index'
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails routes -g show` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output

      output = Dir.chdir(app_path) { `bin/rails routes -g POST` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n       POST /cart(.:format) cart#create\n", output

      output = Dir.chdir(app_path) { `bin/rails routes -g basketballs` }
      assert_equal "     Prefix Verb URI Pattern            Controller#Action\n" \
                   "basketballs GET  /basketballs(.:format) basketball#index\n", output
    end

    def test_rails_routes_with_controller_search_key
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
          get '/basketball', to: 'basketball#index'
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails routes -c cart` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output

      output = Dir.chdir(app_path) { `bin/rails routes -c Cart` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output

      output = Dir.chdir(app_path) { `bin/rails routes -c CartController` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output
    end

    def test_rails_routes_with_namespaced_controller_search_key
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          namespace :admin do
            resource :post
          end
        end
      RUBY
      expected_output = ["         Prefix Verb   URI Pattern                Controller#Action",
                         " new_admin_post GET    /admin/post/new(.:format)  admin/posts#new",
                         "edit_admin_post GET    /admin/post/edit(.:format) admin/posts#edit",
                         "     admin_post GET    /admin/post(.:format)      admin/posts#show",
                         "                PATCH  /admin/post(.:format)      admin/posts#update",
                         "                PUT    /admin/post(.:format)      admin/posts#update",
                         "                DELETE /admin/post(.:format)      admin/posts#destroy",
                         "                POST   /admin/post(.:format)      admin/posts#create\n"].join("\n")

      output = Dir.chdir(app_path) { `bin/rails routes -c Admin::PostController` }
      assert_equal expected_output, output

      output = Dir.chdir(app_path) { `bin/rails routes -c PostController` }
      assert_equal expected_output, output
    end

    def test_rails_routes_displays_message_when_no_routes_are_defined
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
        end
      RUBY

      assert_equal <<-MESSAGE.strip_heredoc, Dir.chdir(app_path) { `bin/rails routes` }
        You don't have any routes defined!

        Please add some routes in config/routes.rb.

        For more information about routes, see the Rails guide: http://guides.rubyonrails.org/routing.html.
      MESSAGE
    end

    def test_rake_routes_with_rake_options
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rake --rakefile Rakefile routes` }
      assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output
    end

    def test_logger_is_flushed_when_exiting_production_rake_tasks
      add_to_config <<-RUBY
        rake_tasks do
          task log_something: :environment do
            Rails.logger.error("Sample log message")
          end
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails log_something RAILS_ENV=production && cat log/production.log` }
      assert_match "Sample log message", output
    end

    def test_loading_specific_fixtures
      Dir.chdir(app_path) do
        `bin/rails generate model user username:string password:string;
         bin/rails generate model product name:string;
         bin/rails db:migrate`
      end

      require "#{rails_root}/config/environment"

      # loading a specific fixture
      errormsg = Dir.chdir(app_path) { `bin/rails db:fixtures:load FIXTURES=products` }
      assert $?.success?, errormsg

      assert_equal 2, ::AppTemplate::Application::Product.count
      assert_equal 0, ::AppTemplate::Application::User.count
    end

    def test_loading_only_yml_fixtures
      Dir.chdir(app_path) do
        `bin/rails db:migrate`
      end

      app_file "test/fixtures/products.csv", ""

      require "#{rails_root}/config/environment"
      errormsg = Dir.chdir(app_path) { `bin/rails db:fixtures:load` }
      assert $?.success?, errormsg
    end

    def test_scaffold_tests_pass_by_default
      output = Dir.chdir(app_path) do
        `bin/rails generate scaffold user username:string password:string;
         RAILS_ENV=test bin/rails db:migrate test`
      end

      assert_match(/7 runs, 9 assertions, 0 failures, 0 errors/, output)
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

      output = Dir.chdir(app_path) do
        `bin/rails generate scaffold user username:string password:string;
         RAILS_ENV=test bin/rails db:migrate test`
      end

      assert_match(/5 runs, 7 assertions, 0 failures, 0 errors/, output)
      assert_no_match(/Errors running/, output)
    end

    def test_scaffold_with_references_columns_tests_pass_by_default
      output = Dir.chdir(app_path) do
        `bin/rails generate model Product;
         bin/rails generate model Cart;
         bin/rails generate scaffold LineItems product:references cart:belongs_to;
         RAILS_ENV=test bin/rails db:migrate test`
      end

      assert_match(/7 runs, 9 assertions, 0 failures, 0 errors/, output)
      assert_no_match(/Errors running/, output)
    end

    def test_db_test_prepare_when_using_sql_format
      add_to_config "config.active_record.schema_format = :sql"
      output = Dir.chdir(app_path) do
        `bin/rails generate scaffold user username:string;
         bin/rails db:migrate;
         bin/rails db:test:prepare 2>&1 --trace`
      end
      assert_match(/Execute db:test:load_structure/, output)
    end

    def test_rake_dump_structure_should_respect_db_structure_env_variable
      Dir.chdir(app_path) do
        # ensure we have a schema_migrations table to dump
        `bin/rails db:migrate db:structure:dump SCHEMA=db/my_structure.sql`
      end
      assert File.exist?(File.join(app_path, "db", "my_structure.sql"))
    end

    def test_rake_dump_structure_should_be_called_twice_when_migrate_redo
      add_to_config "config.active_record.schema_format = :sql"

      output = Dir.chdir(app_path) do
        `bin/rails g model post title:string;
         bin/rails db:migrate:redo 2>&1 --trace;`
      end

      # expect only Invoke db:structure:dump (first_time)
      assert_no_match(/^\*\* Invoke db:structure:dump\s+$/, output)
    end

    def test_rake_dump_schema_cache
      Dir.chdir(app_path) do
        `bin/rails generate model post title:string;
         bin/rails generate model product name:string;
         bin/rails db:migrate db:schema:cache:dump`
      end
      assert File.exist?(File.join(app_path, "db", "schema_cache.yml"))
    end

    def test_rake_clear_schema_cache
      Dir.chdir(app_path) do
        `bin/rails db:schema:cache:dump db:schema:cache:clear`
      end
      assert !File.exist?(File.join(app_path, "db", "schema_cache.yml"))
    end

    def test_copy_templates
      Dir.chdir(app_path) do
        `bin/rails app:templates:copy`
        %w(controller mailer scaffold).each do |dir|
          assert File.exist?(File.join(app_path, "lib", "templates", "erb", dir))
        end
        %w(controller helper scaffold_controller assets).each do |dir|
          assert File.exist?(File.join(app_path, "lib", "templates", "rails", dir))
        end
      end
    end

    def test_template_load_initializers
      app_file "config/initializers/dummy.rb", "puts 'Hello, World!'"
      app_file "template.rb", ""

      output = Dir.chdir(app_path) do
        `bin/rails app:template LOCATION=template.rb`
      end

      assert_match(/Hello, World!/, output)
    end

    def test_tmp_clear_should_work_if_folder_missing
      FileUtils.remove_dir("#{app_path}/tmp")
      errormsg = Dir.chdir(app_path) { `bin/rails tmp:clear` }
      assert_predicate $?, :success?
      assert_empty errormsg
    end
  end
end
