require 'rails/generators/app_base'
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
      directory "lib"
    end

    def test
      directory "test"
    end

    def generate_test_dummy
      invoke Rails::Generators::AppGenerator,
        [ File.expand_path(dummy_path, destination_root) ], {}
    end

    def test_dummy_config
      store_application_definition!
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
      attr_accessor :rails_template

      add_shebang_option!

      argument :plugin_path,            :type => :string
      alias_method :app_path, :plugin_path

      class_option :builder,            :type => :string, :aliases => "-b",
                                        :desc => "Path to a plugin builder (can be a filesystem path or URL)"

      class_option :template,           :type => :string, :aliases => "-m",
                                        :desc => "Path to an application template (can be a filesystem path or URL)"

      class_option :skip_gemfile,       :type => :boolean, :default => false,
                                        :desc => "Don't create a Gemfile"

      class_option :skip_git,           :type => :boolean, :aliases => "-G", :default => false,
                                        :desc => "Skip Git ignores and keeps"

      class_option :dev,                :type => :boolean, :default => false,
                                        :desc => "Setup the plugin with Gemfile pointing to your Rails checkout"

      class_option :edge,               :type => :boolean, :default => false,
                                        :desc => "Setup the plugin with Gemfile pointing to Rails repository"

      class_option :help,               :type => :boolean, :aliases => "-h", :group => :rails,
                                        :desc => "Show this help message and quit"


      def initialize(*args)
        raise Error, "Options should be given after the plugin name. For details run: rails plugin --help" if args[0].blank?

        super
      end

      say_step "Creating gem skeleton"

      def create_root
        super
      end

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

      say_step "Vendoring Rails application at test/dummy"

      def create_test_dummy_files
        build(:generate_test_dummy)
      end

      say_step "Configuring Rails application"

      def change_config_files
        build(:test_dummy_config)
      end

      say_step "Removing unneeded files"

      def remove_uneeded_rails_files
        build(:test_dummy_clean)
      end

      def finish_template
        build(:leftovers)
      end

      def apply_rails_template
        super
      end

      def bundle_if_dev_or_edge
        super
      end

    protected

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
          unless options[:pretend]
            contents = File.read(File.expand_path("#{dummy_path}/config/application.rb", destination_root))
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
    end
  end
end
