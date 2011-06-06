require "isolation/abstract_unit"

module ApplicationTests
  class RakeTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
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

    def test_environment_is_required_in_rake_tasks
      app_file "config/environment.rb", <<-RUBY
        SuperMiddleware = Struct.new(:app)

        AppTemplate::Application.configure do
          config.middleware.use SuperMiddleware
        end

        AppTemplate::Application.initialize!
      RUBY

      assert_match "SuperMiddleware", Dir.chdir(app_path){ `rake middleware` }
    end

    def test_code_statistics_sanity
      assert_match "Code LOC: 5     Test LOC: 0     Code to Test Ratio: 1:0.0",
        Dir.chdir(app_path){ `rake stats` }
    end

    def test_rake_routes_output_strips_anchors_from_http_verbs
      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/cart', :to => 'cart#show'
        end
      RUBY
      assert_match 'cart GET /cart(.:format)', Dir.chdir(app_path){ `rake routes` }
    end
  end
end
