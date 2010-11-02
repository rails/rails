require 'active_support/core_ext/hash/slice'
require "rails/generators/rails/app/app_generator"

module Rails
  class PluginBuilder
    def rakefile
      template "Rakefile"
    end

    def readme
      copy_file "README.rdoc"
    end

    def gemfile
      template "Gemfile"
    end

    def license
      template "MIT-LICENSE"
    end

    def gemspec
      template "%name%.gemspec"
    end

    def gitignore
      copy_file "gitignore", ".gitignore"
    end

    def lib
      template "lib/%name%.rb"
      if full?
        template "lib/%name%/engine.rb"
      end
    end

    def test
      template "test/test_helper.rb"
      template "test/%name%_test.rb"
      if full?
        template "test/integration/navigation_test.rb"
      end
    end

    def generate_test_dummy
      opts = (options || {}).slice(:skip_active_record, :skip_javascript, :database, :javascript)

      invoke Rails::Generators::AppGenerator,
        [ File.expand_path(dummy_path, destination_root) ], opts
    end

    def test_dummy_config
      template "rails/boot.rb", "#{dummy_path}/config/boot.rb", :force => true
      template "rails/application.rb", "#{dummy_path}/config/application.rb", :force => true
    end

    def test_dummy_clean
      inside dummy_path do
        remove_file ".gitignore"
        remove_file "db/seeds.rb"
        remove_file "doc"
        remove_file "Gemfile"
        remove_file "lib/tasks"
        remove_file "public/images/rails.png"
        remove_file "public/index.html"
        remove_file "public/robots.txt"
        remove_file "README"
        remove_file "test"
        remove_file "vendor"
      end
    end

    def script
      directory "script" do |content|
        "#{shebang}\n" + content
      end
      chmod "script", 0755, :verbose => false
    end

    def rakefile_test_tasks
      <<-RUBY
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end
      RUBY
    end

    def dummy_path
      "#{test_path}/dummy"
    end

    def test_path
      "test"
    end
  end

  module Generators
    class PluginNewGenerator < AppBase
      add_shared_options_for "plugin"

      alias_method :plugin_path, :app_path

      class_option :full, :type => :boolean, :default => false,
                          :desc => "Generate rails engine with integration tests"

      def initialize(*args)
        raise Error, "Options should be given after the plugin name. For details run: rails plugin --help" if args[0].blank?

        super
      end

      public_task :create_root

      def create_root_files
        build(:readme)
        build(:rakefile)
        build(:gemspec)
        build(:license)
        build(:gitignore) unless options[:skip_git]
        build(:gemfile)   unless options[:skip_gemfile]
      end

      def create_config_files
        build(:config)
      end

      def create_lib_files
        build(:lib)
      end

      def create_script_files
        build(:script)
      end

      def create_test_files
        build(:test) unless options[:skip_test_unit]
      end

      def create_test_dummy_files
        return if options[:skip_test_unit]
        create_test_dummy(dummy_path)
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template, :bundle_if_dev_or_edge

    protected
      def create_test_dummy(dummy_path)
        say_status :vendor_app, dummy_path
        mute do
          build(:generate_test_dummy)
          store_application_definition!
          build(:test_dummy_config)
          build(:test_dummy_clean)
        end
      end

      def full?
        options[:full]
      end

      def self.banner
        "rails plugin new #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      def name
        @name ||= File.basename(destination_root)
      end

      def camelized
        @camelized ||= name.gsub(/\W/, '_').squeeze('_').camelize
      end

      def valid_const?
        if camelized =~ /^\d/
          raise Error, "Invalid plugin name #{name}. Please give a name which does not start with numbers."
        elsif RESERVED_NAMES.include?(name)
          raise Error, "Invalid plugin name #{name}. Please give a name which does not match one of the reserved rails words."
        elsif Object.const_defined?(camelized)
          raise Error, "Invalid plugin name #{name}, constant #{camelized} is already in use. Please choose another application name."
        end
      end

      def application_definition
        @application_definition ||= begin

          dummy_application_path = File.expand_path("#{dummy_path}/config/application.rb", destination_root)
          unless options[:pretend] || !File.exists?(dummy_application_path)
            contents = File.read(dummy_application_path)
            contents[(contents.index("module Dummy"))..-1]
          end
        end
      end
      alias :store_application_definition! :application_definition

      def get_builder_class
        defined?(::PluginBuilder) ? ::PluginBuilder : Rails::PluginBuilder
      end

      [:test_path, :dummy_path, :rakefile_test_tasks].each do |name|
        define_method name do
          builder.send(name) if builder.respond_to?(name)
        end
      end

      def mute(&block)
        shell.mute(&block)
      end
    end
  end
end
