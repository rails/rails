require 'rails/generators/app_base'

module Rails
  module ActionMethods
    attr_reader :options

    def initialize(generator)
      @generator = generator
      @options   = generator.options
    end

  private

    def method_missing(meth, *args, &block)
      @generator.send(meth, *args, &block)
    end
  end

  # The application builder allows you to override elements of the application
  # generator without being forced to reverse the operations of the default
  # generator.
  #
  # This allows you to override entire operations, like the creation of the
  # Gemfile, README, or javascript files, without needing to know exactly
  # what those operations do so you can create another template action.
  class AppBuilder
    def rakefile
      template "Rakefile"
    end

    def readme
      copy_file "README"
    end

    def gemfile
      template "Gemfile"
    end

    def configru
      template "config.ru"
    end

    def gitignore
      copy_file "gitignore", ".gitignore"
    end

    def app
      directory 'app'
    end

    def config
      empty_directory "config"

      inside "config" do
        template "routes.rb"
        template "application.rb"
        template "environment.rb"

        directory "environments"
        directory "initializers"
        directory "locales"
      end
    end

    def database_yml
      template "config/databases/#{options[:database]}.yml", "config/database.yml"
    end

    def db
      directory "db"
    end

    def doc
      directory "doc"
    end

    def lib
      empty_directory "lib"
      empty_directory_with_gitkeep "lib/tasks"
    end

    def log
      empty_directory "log"

      inside "log" do
        %w( server production development test ).each do |file|
          create_file "#{file}.log"
          chmod "#{file}.log", 0666, :verbose => false
        end
      end
    end

    def public_directory
      directory "public", "public", :recursive => false
    end

    def images
      directory "public/images"
    end

    def stylesheets
      empty_directory_with_gitkeep "public/stylesheets"
    end

    def javascripts
      empty_directory "public/javascripts"

      unless options[:skip_javascript]
        copy_file "public/javascripts/#{options[:javascript]}.js"
        copy_file "public/javascripts/#{options[:javascript]}_ujs.js", "public/javascripts/rails.js"

        if options[:javascript] == "prototype"
          copy_file "public/javascripts/controls.js"
          copy_file "public/javascripts/dragdrop.js"
          copy_file "public/javascripts/effects.js"
        end
      end

      copy_file "public/javascripts/application.js"
    end

    def script
      directory "script" do |content|
        "#{shebang}\n" + content
      end
      chmod "script", 0755, :verbose => false
    end

    def test
      directory "test"
    end

    def tmp
      empty_directory "tmp"

      inside "tmp" do
        %w(sessions sockets cache pids).each do |dir|
          empty_directory(dir)
        end
      end
    end

    def vendor_plugins
      empty_directory_with_gitkeep "vendor/plugins"
    end
  end

  module Generators
    # We need to store the RAILS_DEV_PATH in a constant, otherwise the path
    # can change in Ruby 1.8.7 when we FileUtils.cd.
    RAILS_DEV_PATH = File.expand_path("../../../../../..", File.dirname(__FILE__))

    RESERVED_NAMES = %w[application destroy benchmarker profiler
                        plugin runner test]

    class AppGenerator < AppBase
      add_shared_options_for "application"

      # Add bin/rails options
      class_option :version,            :type => :boolean, :aliases => "-v", :group => :rails,
                                        :desc => "Show Rails version number and quit"

      def initialize(*args)
        raise Error, "Options should be given after the application name. For details run: rails --help" if args[0].blank?

        super

        if !options[:skip_active_record] && !DATABASES.include?(options[:database])
          raise Error, "Invalid value for --database option. Supported for preconfiguration are: #{DATABASES.join(", ")}."
        end
        
        if !options[:skip_javascript] && !JAVASCRIPTS.include?(options[:javascript])
          raise Error, "Invalid value for --javascript option. Supported for preconfiguration are: #{JAVASCRIPTS.join(", ")}."
        end
      end

      public_task :create_root

      def create_root_files
        build(:readme)
        build(:rakefile)
        build(:configru)
        build(:gitignore) unless options[:skip_git]
        build(:gemfile)   unless options[:skip_gemfile]
      end

      def create_app_files
        build(:app)
      end

      def create_config_files
        build(:config)
      end

      def create_boot_file
        template "config/boot.rb"
      end

      def create_active_record_files
        return if options[:skip_active_record]
        build(:database_yml)
      end

      def create_db_files
        build(:db)
      end

      def create_doc_files
        build(:doc)
      end

      def create_lib_files
        build(:lib)
      end

      def create_log_files
        build(:log)
      end

      def create_public_files
        build(:public_directory)
      end

      def create_public_image_files
        build(:images)
      end

      def create_public_stylesheets_files
        build(:stylesheets)
      end

      def create_javascript_files
        build(:javascripts)
      end

      def create_script_files
        build(:script)
      end

      def create_test_files
        build(:test) unless options[:skip_test_unit]
      end

      def create_tmp_files
        build(:tmp)
      end

      def create_vendor_files
        build(:vendor_plugins)
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template, :bundle_if_dev_or_edge

    protected

      def self.banner
        "rails new #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      # Define file as an alias to create_file for backwards compatibility.
      def file(*args, &block)
        create_file(*args, &block)
      end

      def app_name
        @app_name ||= defined_app_const_base? ? defined_app_name : File.basename(destination_root)
      end

      def defined_app_name
        defined_app_const_base.underscore
      end

      def defined_app_const_base
        Rails.respond_to?(:application) && defined?(Rails::Application) &&
          Rails.application.is_a?(Rails::Application) && Rails.application.class.name.sub(/::Application$/, "")
      end

      alias :defined_app_const_base? :defined_app_const_base

      def app_const_base
        @app_const_base ||= defined_app_const_base || app_name.gsub(/\W/, '_').squeeze('_').camelize
      end
      alias :camelized :app_const_base

      def app_const
        @app_const ||= "#{app_const_base}::Application"
      end

      def valid_const?
        if app_const =~ /^\d/
          raise Error, "Invalid application name #{app_name}. Please give a name which does not start with numbers."
        elsif RESERVED_NAMES.include?(app_name)
          raise Error, "Invalid application name #{app_name}. Please give a name which does not match one of the reserved rails words."
        elsif Object.const_defined?(app_const_base)
          raise Error, "Invalid application name #{app_name}, constant #{app_const_base} is already in use. Please choose another application name."
        end
      end

      def app_secret
        ActiveSupport::SecureRandom.hex(64)
      end

      def mysql_socket
        @mysql_socket ||= [
          "/tmp/mysql.sock",                        # default
          "/var/run/mysqld/mysqld.sock",            # debian/gentoo
          "/var/tmp/mysql.sock",                    # freebsd
          "/var/lib/mysql/mysql.sock",              # fedora
          "/opt/local/lib/mysql/mysql.sock",        # fedora
          "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
          "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
          "/opt/local/var/run/mysql5/mysqld.sock",  # mac + darwinports + mysql5
          "/opt/lampp/var/mysql/mysql.sock"         # xampp for linux
        ].find { |f| File.exist?(f) } unless RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
      end

      def get_builder_class
        defined?(::AppBuilder) ? ::AppBuilder : Rails::AppBuilder
      end
    end
  end
end
