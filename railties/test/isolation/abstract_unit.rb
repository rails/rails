# Note:
# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.
require 'fileutils'

# TODO: Remove rubygems when possible
require 'rubygems'
require 'test/unit'

# TODO: Remove setting this magic constant
RAILS_FRAMEWORK_ROOT = File.expand_path("#{File.dirname(__FILE__)}/../../..")

# These files do not require any others and are needed
# to run the tests
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/testing/isolation"
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/testing/declarative"
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/core_ext/kernel/reporting"

module TestHelpers
  module Paths
    module_function

    TMP_PATH = File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. tmp]))

    def tmp_path(*args)
      File.join(TMP_PATH, *args)
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
        require "#{app_path}/config/environment"
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
      assert_equal 200, resp[0]
      assert resp[1]["Content-Type"] = "text/html"
      assert extract_body(resp).match(/Welcome aboard/)
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
      @prev_rails_env = ENV['RAILS_ENV']
      ENV['RAILS_ENV'] = 'development'

      FileUtils.rm_rf(app_path)
      FileUtils.cp_r(tmp_path('app_template'), app_path)

      # Delete the initializers unless requested
      unless options[:initializers]
        Dir["#{app_path}/config/initializers/*.rb"].each do |initializer|
          File.delete(initializer)
        end
      end

      unless options[:gemfile]
        File.delete"#{app_path}/Gemfile"
      end

      routes = File.read("#{app_path}/config/routes.rb")
      if routes =~ /(\n\s*end\s*)\Z/
        File.open("#{app_path}/config/routes.rb", 'w') do |f|
          f.puts $` + "\nmatch ':controller(/:action(/:id))(.:format)'\n" + $1
        end
      end

      add_to_config 'config.secret_token = "3b7cd727ee24e8444053437c36cc66c4"; config.session_store :cookie_store, :key => "_myapp_session"; config.active_support.deprecation = :log'
    end

    def teardown_app
      ENV['RAILS_ENV'] = @prev_rails_env if @prev_rails_env
    end

    # Make a very basic app, without creating the whole directory structure.
    # This is faster and simpler than the method above.
    def make_basic_app
      require "rails"
      require "action_controller/railtie"

      app = Class.new(Rails::Application)
      app.config.secret_token = "3b7cd727ee24e8444053437c36cc66c4"
      app.config.session_store :cookie_store, :key => "_myapp_session"
      app.config.active_support.deprecation = :log

      yield app if block_given?
      app.initialize!

      app.routes.draw do
        match "/" => "omg#index"
      end

      require 'rack/test'
      extend ::Rack::Test::Methods
    end

    def simple_controller
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render :text => "foo"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          match ':controller(/:action)'
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

    def plugin(name, string = "")
      dir = "#{app_path}/vendor/plugins/#{name}"
      FileUtils.mkdir_p(dir)

      File.open("#{dir}/init.rb", 'w') do |f|
        f.puts "::#{name.upcase} = 'loaded'"
        f.puts string
      end

      Bukkit.new(dir).tap do |bukkit|
        yield bukkit if block_given?
      end
    end

    def engine(name)
      dir = "#{app_path}/random/#{name}"
      FileUtils.mkdir_p(dir)

      app = File.readlines("#{app_path}/config/application.rb")
      app.insert(2, "$:.unshift(\"#{dir}/lib\")")
      app.insert(3, "require #{name.inspect}")

      File.open("#{app_path}/config/application.rb", 'r+') do |f|
        f.puts app
      end

      Bukkit.new(dir).tap do |bukkit|
        yield bukkit if block_given?
      end
    end

    def script(script)
      Dir.chdir(app_path) do
        `#{Gem.ruby} #{app_path}/script/rails #{script}`
      end
    end

    def add_to_config(str)
      environment = File.read("#{app_path}/config/application.rb")
      if environment =~ /(\n\s*end\s*end\s*)\Z/
        File.open("#{app_path}/config/application.rb", 'w') do |f|
          f.puts $` + "\n#{str}\n" + $1
        end
      end
    end

    def add_to_env_config(env, str)
      environment = File.read("#{app_path}/config/environments/#{env}.rb")
      if environment =~ /(\n\s*end\s*)\Z/
        File.open("#{app_path}/config/environments/#{env}.rb", 'w') do |f|
          f.puts $` + "\n#{str}\n" + $1
        end
      end
    end

    def remove_from_config(str)
      file = "#{app_path}/config/application.rb"
      contents = File.read(file)
      contents.sub!(/#{str}/, "")
      File.open(file, "w+") { |f| f.puts contents }
    end

    def app_file(path, contents)
      FileUtils.mkdir_p File.dirname("#{app_path}/#{path}")
      File.open("#{app_path}/#{path}", 'w') do |f|
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
      to_remove =  [:actionmailer,
                    :activemodel,
                    :activerecord,
                    :activeresource] - arr
      remove_from_config "config.active_record.identity_map = true" if to_remove.include? :activerecord
      $:.reject! {|path| path =~ %r'/(#{to_remove.join('|')})/' }
    end

    def boot_rails
      require File.expand_path('../../../../load_paths', __FILE__)
    end
  end
end

class Test::Unit::TestCase
  include TestHelpers::Paths
  include TestHelpers::Rack
  include TestHelpers::Generation
  extend  ActiveSupport::Testing::Declarative
end

# Create a scope and build a fixture rails app
Module.new do
  extend TestHelpers::Paths
  # Build a rails app
  if File.exist?(tmp_path)
    FileUtils.rm_rf(tmp_path)
  end
  FileUtils.mkdir(tmp_path)

  environment = File.expand_path('../../../../load_paths', __FILE__)
  if File.exist?("#{environment}.rb")
    require_environment = "-r #{environment}"
  end

  `#{Gem.ruby} #{require_environment} #{RAILS_FRAMEWORK_ROOT}/bin/rails new #{tmp_path('app_template')}`
  File.open("#{tmp_path}/app_template/config/boot.rb", 'w') do |f|
    if require_environment
      f.puts "Dir.chdir('#{File.dirname(environment)}') do"
      f.puts "  require '#{environment}'"
      f.puts "end"
    end
    f.puts "require 'rails/all'"
  end
end
