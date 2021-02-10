# frozen_string_literal: true

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
require "active_support/testing/method_call_assertions"
require "active_support/test_case"
require "minitest/retry"

if ENV["BUILDKITE"]
  Minitest::Retry.use!(verbose: false, retry_count: 1)
end

RAILS_FRAMEWORK_ROOT = File.expand_path("../../..", __dir__)

# These files do not require any others and are needed
# to run the tests
require "active_support/core_ext/object/blank"
require "active_support/testing/isolation"
require "active_support/core_ext/kernel/reporting"
require "tmpdir"
require "rails/secrets"

module TestHelpers
  module Paths
    def app_template_path
      File.join RAILS_FRAMEWORK_ROOT, "tmp/templates/app_template"
    end

    def tmp_path(*args)
      @tmp_path ||= File.realpath(Dir.mktmpdir(nil, File.join(RAILS_FRAMEWORK_ROOT, "tmp")))
      File.join(@tmp_path, *args)
    end

    def app_path(*args)
      path = tmp_path(*%w[app] + args)
      if block_given?
        yield path
      else
        path
      end
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

        require "#{app_path}/config/environment"

        Rails.application
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def extract_body(response)
      (+"").tap do |body|
        response[2].each { |chunk| body << chunk }
      end
    end

    def get(path)
      @app.call(::Rack::MockRequest.env_for(path, "HTTP_HOST" => "example.com"))
    end

    def assert_welcome(resp)
      resp = Array(resp)

      assert_equal 200, resp[0]
      assert_match "text/html", resp[1]["Content-Type"]
      assert_match "charset=utf-8", resp[1]["Content-Type"]
      assert extract_body(resp).match(/Yay! You.*re on Rails!/)
    end
  end

  module Generation
    # Build an application by invoking the generator and going through the whole stack.
    def build_app(options = {})
      @prev_rails_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      FileUtils.rm_rf(app_path)
      FileUtils.cp_r(app_template_path, app_path)

      # Delete the initializers unless requested
      unless options[:initializers]
        Dir["#{app_path}/config/initializers/**/*.rb"].each do |initializer|
          File.delete(initializer)
        end
      end

      routes = File.read("#{app_path}/config/routes.rb")
      if routes =~ /(\n\s*end\s*)\z/
        File.open("#{app_path}/config/routes.rb", "w") do |f|
          f.puts $` + "\nActiveSupport::Deprecation.silence { match ':controller(/:action(/:id))(.:format)', via: :all }\n" + $1
        end
      end

      if options[:multi_db]
        File.open("#{app_path}/config/database.yml", "w") do |f|
          f.puts <<-YAML
          default: &default
            adapter: sqlite3
            pool: 5
            timeout: 5000
            variables:
              statement_timeout: 1000
          development:
            primary:
              <<: *default
              database: db/development.sqlite3
            primary_readonly:
              <<: *default
              database: db/development.sqlite3
              replica: true
            animals:
              <<: *default
              database: db/development_animals.sqlite3
              migrations_paths: db/animals_migrate
            animals_readonly:
              <<: *default
              database: db/development_animals.sqlite3
              migrations_paths: db/animals_migrate
              replica: true
          test:
            primary:
              <<: *default
              database: db/test.sqlite3
            primary_readonly:
              <<: *default
              database: db/test.sqlite3
              replica: true
            animals:
              <<: *default
              database: db/test_animals.sqlite3
              migrations_paths: db/animals_migrate
            animals_readonly:
              <<: *default
              database: db/test_animals.sqlite3
              migrations_paths: db/animals_migrate
              replica: true
          production:
            primary:
              <<: *default
              database: db/production.sqlite3
            primary_readonly:
              <<: *default
              database: db/production.sqlite3
              replica: true
            animals:
              <<: *default
              database: db/production_animals.sqlite3
              migrations_paths: db/animals_migrate
            animals_readonly:
              <<: *default
              database: db/production_animals.sqlite3
              migrations_paths: db/animals_migrate
              replica: true
          YAML
        end
      else
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
      end

      add_to_config <<-RUBY
        config.hosts << proc { true }
        config.eager_load = false
        config.session_store :cookie_store, key: "_myapp_session"
        config.active_support.deprecation = :log
        config.action_controller.allow_forgery_protection = false
      RUBY
    end

    def teardown_app
      ENV["RAILS_ENV"] = @prev_rails_env if @prev_rails_env
      FileUtils.rm_rf(tmp_path)
    end

    # Make a very basic app, without creating the whole directory structure.
    # This is faster and simpler than the method above.
    def make_basic_app
      require "rails"
      require "action_controller/railtie"
      require "action_view/railtie"

      @app = Class.new(Rails::Application) do
        def self.name; "RailtiesTestApp"; end
      end
      @app.config.hosts << proc { true }
      @app.config.eager_load = false
      @app.config.session_store :cookie_store, key: "_myapp_session"
      @app.config.active_support.deprecation = :log
      @app.config.log_level = :info
      @app.secrets.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"

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
            render plain: "foo"
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
        File.open(path, "w") { |f| f.puts string }
      end

      def delete(file)
        File.delete("#{@path}/#{file}")
      end
    end

    def engine(name)
      dir = "#{app_path}/random/#{name}"
      FileUtils.mkdir_p(dir)

      app = File.readlines("#{app_path}/config/application.rb")
      app.insert(4, "$:.unshift(\"#{dir}/lib\")")
      app.insert(5, "require #{name.inspect}")

      File.open("#{app_path}/config/application.rb", "r+") do |f|
        f.puts app
      end

      Bukkit.new(dir).tap do |bukkit|
        yield bukkit if block_given?
      end
    end

    # Invoke a bin/rails command inside the app
    #
    # allow_failure:: true to return normally if the command exits with
    #   a non-zero status. By default, this method will raise.
    # stderr:: true to pass STDERR output straight to the "real" STDERR.
    #   By default, the STDERR and STDOUT of the process will be
    #   combined in the returned string.
    def rails(*args, allow_failure: false, stderr: false)
      args = args.flatten
      fork = true

      command = "bin/rails #{Shellwords.join args}#{' 2>&1' unless stderr}"

      # Don't fork if the environment has disabled it
      fork = false if ENV["NO_FORK"]

      # Don't fork if the runtime isn't able to
      fork = false if !Process.respond_to?(:fork)

      # Don't fork if we're re-invoking minitest
      fork = false if args.first == "t" || args.grep(/\Atest(:|\z)/).any?

      if fork
        out_read, out_write = IO.pipe
        if stderr
          err_read, err_write = IO.pipe
        else
          err_write = out_write
        end

        pid = fork do
          out_read.close
          err_read.close if err_read

          $stdin.reopen(File::NULL, "r")
          $stdout.reopen(out_write)
          $stderr.reopen(err_write)

          at_exit do
            case $!
            when SystemExit
              exit! $!.status
            when nil
              exit! 0
            else
              err_write.puts "#{$!.class}: #{$!}"
              exit! 1
            end
          end

          Rails.instance_variable_set :@_env, nil

          $-v = $-w = false
          Dir.chdir app_path unless Dir.pwd == app_path

          ARGV.replace(args)
          load "./bin/rails"

          exit! 0
        end

        out_write.close

        if err_read
          err_write.close

          $stderr.write err_read.read
        end

        output = out_read.read

        Process.waitpid pid

      else
        output = `cd #{app_path}; #{command}`
      end

      raise "rails command failed (#{$?.exitstatus}): #{command}\n#{output}" unless allow_failure || $?.success?

      output
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
      if environment =~ /(\n\s*end\s*end\s*)\z/
        File.open("#{app_path}/config/application.rb", "w") do |f|
          f.puts $` + "\n#{str}\n" + $1
        end
      end
    end

    def add_to_env_config(env, str)
      environment = File.read("#{app_path}/config/environments/#{env}.rb")
      if environment =~ /(\n\s*end\s*)\z/
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
      file_name = "#{app_path}/#{path}"
      FileUtils.mkdir_p File.dirname(file_name)
      File.open(file_name, mode) do |f|
        f.puts contents
      end
      file_name
    end

    def app_dir(path)
      FileUtils.mkdir_p("#{app_path}/#{path}")
    end

    def remove_file(path)
      FileUtils.rm_rf "#{app_path}/#{path}"
    end

    def controller(name, contents)
      app_file("app/controllers/#{name}_controller.rb", contents)
    end

    def use_frameworks(arr)
      to_remove = [:actionmailer, :activerecord, :activestorage, :activejob, :actionmailbox] - arr

      if to_remove.include?(:activerecord)
        remove_from_config "config.active_record.*"
      end

      $:.reject! { |path| path =~ %r'/(#{to_remove.join('|')})/' }
    end

    def use_postgresql(multi_db: false)
      if multi_db
        File.open("#{app_path}/config/database.yml", "w") do |f|
          f.puts <<-YAML
          default: &default
            adapter: postgresql
            pool: 5
          development:
            primary:
              <<: *default
              database: railties_test
            animals:
              <<: *default
              database: railties_animals_test
              migrations_paths: db/animals_migrate
          YAML
        end
      else
        File.open("#{app_path}/config/database.yml", "w") do |f|
          f.puts <<-YAML
          default: &default
            adapter: postgresql
            pool: 5
            database: railties_test
          development:
            <<: *default
          test:
            <<: *default
          YAML
        end
      end
    end
  end

  module Reload
    def reload
      ActiveSupport::Dependencies.clear
    end
  end
end

class ActiveSupport::TestCase
  include TestHelpers::Paths
  include TestHelpers::Rack
  include TestHelpers::Generation
  include TestHelpers::Reload
  include ActiveSupport::Testing::Stream
  include ActiveSupport::Testing::MethodCallAssertions
end

# Create a scope and build a fixture rails app
Module.new do
  extend TestHelpers::Paths

  def self.sh(cmd)
    output = `#{cmd}`
    raise "Command #{cmd.inspect} failed. Output:\n#{output}" unless $?.success?
  end

  # Build a rails app
  FileUtils.rm_rf(app_template_path)
  FileUtils.mkdir_p(app_template_path)

  sh "#{Gem.ruby} #{RAILS_FRAMEWORK_ROOT}/railties/exe/rails new #{app_template_path} --skip-bundle --skip-spring --skip-listen --no-rc --skip-webpack-install --quiet"
  File.open("#{app_template_path}/config/boot.rb", "w") do |f|
    f.puts 'require "rails/all"'
  end

  unless File.exist?("#{RAILS_FRAMEWORK_ROOT}/actionview/lib/assets/compiled/rails-ujs.js")
    Dir.chdir("#{RAILS_FRAMEWORK_ROOT}/actionview") do
      sh "yarn build"
    end
  end

  assets_path = "#{RAILS_FRAMEWORK_ROOT}/railties/test/isolation/assets"
  unless Dir.exist?("#{assets_path}/node_modules")
    Dir.chdir(assets_path) do
      sh "yarn install"
    end
  end

  # Fix relative file paths
  package_json = File.read("#{assets_path}/package.json")
  package_json.gsub!(%r{"file:(\.\./[^"]+)"}) do
    path = Pathname.new($1).expand_path(assets_path).relative_path_from(Pathname.new(app_template_path))
    "\"file:#{path}\""
  end
  File.write("#{app_template_path}/package.json", package_json)

  FileUtils.cp("#{assets_path}/config/webpacker.yml", "#{app_template_path}/config/webpacker.yml")
  FileUtils.cp_r("#{assets_path}/config/webpack", "#{app_template_path}/config/webpack")
  FileUtils.ln_s("#{assets_path}/node_modules", "#{app_template_path}/node_modules")
  FileUtils.chdir(app_template_path) do
    sh "yarn install"
    sh "bin/rails webpacker:binstubs"
  end

  # Fake 'Bundler.require' -- we run using the repo's Gemfile, not an
  # app-specific one: we don't want to require every gem that lists.
  contents = File.read("#{app_template_path}/config/application.rb")
  contents.sub!(/^Bundler\.require.*/, "%w(turbolinks webpacker).each { |r| require r }")
  File.write("#{app_template_path}/config/application.rb", contents)

  require "rails"

  require "active_model"
  require "active_job"
  require "active_record"
  require "action_controller"
  require "action_mailer"
  require "action_view"
  require "active_storage"
  require "action_cable"
  require "action_mailbox"
  require "action_text"
  require "sprockets"

  require "action_view/helpers"
  require "action_dispatch/routing/route_set"
end unless defined?(RAILS_ISOLATED_ENGINE)
