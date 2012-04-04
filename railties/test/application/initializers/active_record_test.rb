require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ActiveRecordTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      @database_url = ENV['DATABASE_URL']
      ENV.delete('DATABASE_URL')
      build_app
      boot_rails
    end

    def teardown
      teardown_app
      ENV['DATABASE_URL'] = @database_url
    end

    test "blows up when no DATABASE_URL env var or database.yml" do
      FileUtils.rm_rf("#{app_path}/config/database.yml")
      boot_rails
      simple_controller

      get '/foo'
      assert last_response.body.include?("We're sorry, but something went wrong (500)")
    end
    
    test "uses DATABASE_URL env var when config/database.yml doesn't exist" do
      database_path = "/db/foo.sqlite3"
      FileUtils.rm_rf("#{app_path}/config/database.yml")
      ENV['DATABASE_URL'] = "sqlite3://#{database_path}"
      simple_controller

      get '/foo'
      assert_equal 'foo', last_response.body
      
      # clean up
      FileUtils.rm("#{app_path}/#{database_path}")
    end

    test "DATABASE_URL env var takes precedence over config/database.yml" do
      database_path = "/db/foo.sqlite3"
      ENV['DATABASE_URL'] = "sqlite3://#{database_path}"
      simple_controller

      get '/foo'
      assert File.read("#{app_path}/log/production.log").include?("DATABASE_URL")

      # clean up
      FileUtils.rm("#{app_path}/#{database_path}")
    end

    test "logs the use of config/database.yml" do
      simple_controller

      get '/foo'
      assert File.read("#{app_path}/log/production.log").include?("database.yml")
    end
  end
end
