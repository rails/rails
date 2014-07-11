require 'isolation/abstract_unit'

module ApplicationTests
  class TestTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    test "truth" do
      app_file 'test/unit/foo_test.rb', <<-RUBY
        require 'test_helper'

        class FooTest < ActiveSupport::TestCase
          def test_truth
            assert true
          end
        end
      RUBY

      assert_successful_test_run 'unit/foo_test.rb'
    end

    test "integration test" do
      controller 'posts', <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      app_file 'app/views/posts/index.html.erb', <<-HTML
        Posts#index
      HTML

      app_file 'test/integration/posts_test.rb', <<-RUBY
        require 'test_helper'

        class PostsTest < ActionDispatch::IntegrationTest
          def test_index
            get '/posts'
            assert_response :success
            assert_template "index"
          end
        end
      RUBY

      assert_successful_test_run 'integration/posts_test.rb'
    end

    test "enable full backtraces on test failures" do
      app_file 'test/unit/failing_test.rb', <<-RUBY
        require 'test_helper'

        class FailingTest < ActiveSupport::TestCase
          def test_failure
            raise "fail"
          end
        end
      RUBY

      output = run_test_file('unit/failing_test.rb', env: { "BACKTRACE" => "1" })
      assert_match %r{/app/test/unit/failing_test\.rb}, output
    end

    test "migrations" do
      output  = script('generate model user name:string')
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file 'test/models/user_test.rb', <<-RUBY
        require 'test_helper'

        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon"
          end
        end
      RUBY
      app_file 'db/schema.rb', ''

      assert_unsuccessful_run "models/user_test.rb", "Migrations are pending"

      app_file 'db/schema.rb', <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      app_file 'config/initializers/disable_maintain_test_schema.rb', <<-RUBY
        Rails.application.config.active_record.maintain_test_schema = false
      RUBY

      assert_unsuccessful_run "models/user_test.rb", "Could not find table 'users'"

      File.delete "#{app_path}/config/initializers/disable_maintain_test_schema.rb"

      result = assert_successful_test_run('models/user_test.rb')
      assert !result.include?("create_table(:users)")
    end

    private
      def assert_unsuccessful_run(name, message)
        result = run_test_file(name)
        assert_not_equal 0, $?.to_i
        assert result.include?(message)
        result
      end

      def assert_successful_test_run(name)
        result = run_test_file(name)
        assert_equal 0, $?.to_i, result
        result
      end

      def run_test_file(name, options = {})
        ruby '-Itest', "#{app_path}/test/#{name}", options
      end

      def ruby(*args)
        options = args.extract_options!
        env = options.fetch(:env, {})
        env["RUBYLIB"] = $:.join(':')

        Dir.chdir(app_path) do
          `#{env_string(env)} #{Gem.ruby} #{args.join(' ')} 2>&1`
        end
      end

      def env_string(variables)
        variables.map do |key, value|
          "#{key}='#{value}'"
        end.join " "
      end
  end
end
