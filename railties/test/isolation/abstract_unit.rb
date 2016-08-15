# Note:
# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# Rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.
require "fileutils"

require "bundler/setup" unless defined?(Bundler)
require "active_support"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "active_support/test_case"

RAILS_FRAMEWORK_ROOT = File.expand_path("#{File.dirname(__FILE__)}/../../..")

# These files do not require any others and are needed
# to run the tests
require "active_support/core_ext/object/blank"
require "active_support/testing/isolation"
require "active_support/core_ext/kernel/reporting"
require "tmpdir"

module TestHelpers
  module Paths
    def app_template_path
      File.join Dir.tmpdir, "app_template"
    end

    def tmp_path(*args)
      @tmp_path ||= File.realpath(Dir.mktmpdir)
      File.join(@tmp_path, *args)
    end

    def app_path(*args)
      tmp_path(*%w[app] + args)
    end

    def framework_path
      RAILS_FRAMEWORK_ROOT
    end

    def rails_root
      app_path
    end
  end

  module Rack
    def app(env = "production")
      old_env = ENV["RAILS_ENV"]
      @app ||= begin
        ENV["RAILS_ENV"] = env

        # FIXME: shush Sass warning spam, not relevant to testing Railties
        Kernel.silence_warnings do
          require "#{app_path}/config/environment"
        end

        Rails.application
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def extract_body(response)
      "".tap do |body|
        response[2].each {|chunk| body << chunk }
      end
    end

    def get(path)
      @app.call(::Rack::MockRequest.env_for(path))
    end

    def assert_welcome(resp)
      resp = Array(resp)

      assert_equal 200, resp[0]
      assert_match "text/html", resp[1]["Content-Type"]
      assert_match "charset=utf-8", resp[1]["Content-Type"]
      assert extract_body(resp).match(/Yay! You.*re on Rails!/)
    end

    def assert_success(resp)
      assert_equal 202, resp[0]
    end

    def assert_missing(resp)
      assert_equal 404, resp[0]
    end

    def assert_header(key, value, resp)
      assert_equal value, resp[1][key.to_s]
    end

    def assert_body(expected, resp)
      assert_equal expected, extract_body(resp)
    end
  end

  module Generation
    # Build an application by invoking the generator and going through the whole stack.
    def build_app(options = {})
      @prev_rails_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"]       =   "development"
      ENV["SECRET_KEY_BASE"] ||= SecureRandom.hex(16)

      FileUtils.rm_rf(app_path)
      FileUtils.cp_r(app_template_path, app_path)

      # Delete the initializers unless requested
      unless options[:initializers]
        Dir["#{app_path}/config/initializers/**/*.rb"].each do |initializer|
          File.delete(initializer)
        end
      end

      gemfile_path = "#{app_path}/Gemfile"
      if options[:gemfile].blank? && File.exist?(gemfile_path)
        File.delete gemfile_path
      end

      routes = File.read("#{app_path}/config/routes.rb")
      if routes =~ /(\n\s*end\s*)\Z/
        File.open("#{app_path}/config/routes.rb", "w") do |f|
          f.puts $` + "\nActiveSupport::Deprecation.silence { match ':controller(/:action(/:id))(.:format)', via: :all }\n" + $1
        end
      end

      File.open("#{app_path}/config/database.yml", "w") do |f|
        f.puts <<-YAML
        default: &default
          adapter: sqlite3
          pool: 5
          timeout: 5000
        development:
          <<: *default
          database: db/development.sqlite3
        test:
          <<: *default
          database: db/test.sqlite3
        production:
          <<: *default
          database: db/production.sqlite3
        YAML
      end

      add_to_config <<-RUBY
        config.eager_load = false
        config.session_store :cookie_store, key: "_myapp_session"
        config.active_support.deprecation = :log
        config.active_support.test_order = :random
        config.action_controller.allow_forgery_protection = false
        config.log_level = :info
      RUBY
    end

    def teardown_app
      ENV["RAILS_ENV"] = @prev_rails_env if @prev_rails_env
    end

    # Make a very basic app, without creating the whole directory structure.
    # This is faster and simpler than the method above.
    def make_basic_app
      require "rails"
      require "action_controller/railtie"
      require "action_view/railtie"
      require "action_dispatch/middleware/flash"

      @app = Class.new(Rails::Application)
      @app.config.eager_load = false
      @app.secrets.secret_key_base = "3b7cd727ee24e8444053437c36cc66c4"
      @app.config.session_store :cookie_store, key: "_myapp_session"
      @app.config.active_support.deprecation = :log
      @app.config.active_support.test_order = :random
      @app.config.log_level = :info

      yield @app if block_given?
      @app.initialize!

      @app.routes.draw do
        get "/" => "omg#index"
      end

      require "rack/test"
      extend ::Rack::Test::Methods
    end

    def simple_controller
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render text: "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY
    end

    class Bukkit
      attr_reader :path

      def initialize(path)
        @path = path
      end

      def write(file, string)
        path = "#{@path}/#{file}"
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "w") {|f| f.puts string }
      end

      def delete(file)
        File.delete("#{@path}/#{file}")
      end
    end

    def engine(name)
      dir = "#{app_path}/random/#{name}"
      FileUtils.mkdir_p(dir)

      app = File.readlines("#{app_path}/config/application.rb")
      app.insert(2, "$:.unshift(\"#{dir}/lib\")")
      app.insert(3, "require #{name.inspect}")

      File.open("#{app_path}/config/application.rb", "r+") do |f|
        f.puts app
      end

      Bukkit.new(dir).tap do |bukkit|
        yield bukkit if block_given?
      end
    end

    def script(script)
      Dir.chdir(app_path) do
        `#{Gem.ruby} #{app_path}/bin/rails #{script}`
      end
    end

    def add_to_top_of_config(str)
      environment = File.read("#{app_path}/config/application.rb")
      if environment =~ /(Rails::Application\s*)/
        File.open("#{app_path}/config/application.rb", "w") do |f|
          f.puts $` + $1 + "\n#{str}\n" + $'
        end
      end
    end

    def add_to_config(str)
      environment = File.read("#{app_path}/config/application.rb")
      if environment =~ /(\n\s*end\s*end\s*)\Z/
        File.open("#{app_path}/config/application.rb", "w") do |f|
          f.puts $` + "\n#{str}\n" + $1
        end
      end
    end

    def add_to_env_config(env, str)
      environment = File.read("#{app_path}/config/environments/#{env}.rb")
      if environment =~ /(\n\s*end\s*)\Z/
        File.open("#{app_path}/config/environments/#{env}.rb", "w") do |f|
          f.puts $` + "\n#{str}\n" + $1
        end
      end
    end

    def remove_from_config(str)
      remove_from_file("#{app_path}/config/application.rb", str)
    end

    def remove_from_env_config(env, str)
      remove_from_file("#{app_path}/config/environments/#{env}.rb", str)
    end

    def remove_from_file(file, str)
      contents = File.read(file)
      contents.sub!(/#{str}/, "")
      File.write(file, contents)
    end

    def app_file(path, contents, mode = "w")
      FileUtils.mkdir_p File.dirname("#{app_path}/#{path}")
      File.open("#{app_path}/#{path}", mode) do |f|
        f.puts contents
      end
    end

    def remove_file(path)
      FileUtils.rm_rf "#{app_path}/#{path}"
    end

    def controller(name, contents)
      app_file("app/controllers/#{name}_controller.rb", contents)
    end

    def use_frameworks(arr)
      to_remove = [:actionmailer, :activerecord] - arr

      if to_remove.include?(:activerecord)
        remove_from_config "config.active_record.*"
      end

      $:.reject! {|path| path =~ %r'/(#{to_remove.join('|')})/' }
    end
  end
end

class ActiveSupport::TestCase
  include TestHelpers::Paths
  include TestHelpers::Rack
  include TestHelpers::Generation
  include ActiveSupport::Testing::Stream

  self.test_order = :sorted
end

# Create a scope and build a fixture rails app
Module.new do
  extend TestHelpers::Paths

  # Build a rails app
  FileUtils.rm_rf(app_template_path)
  FileUtils.mkdir(app_template_path)

  `#{Gem.ruby} #{RAILS_FRAMEWORK_ROOT}/railties/exe/rails new #{app_template_path} --skip-gemfile --skip-listen --no-rc`
  File.open("#{app_template_path}/config/boot.rb", "w") do |f|
    f.puts "require 'rails/all'"
  end
end unless defined?(RAILS_ISOLATED_ENGINE)
