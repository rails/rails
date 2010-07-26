require 'digest/md5'
require 'active_support/secure_random'
require 'rails/version' unless defined?(Rails::VERSION)
require 'rbconfig'
require 'open-uri'
require 'uri'

module Rails
  module ActionMethods
    attr_reader :options

    def initialize(generator)
      @generator = generator
      @options   = generator.options
    end

    private
      %w(template copy_file directory empty_directory inside
         empty_directory_with_gitkeep create_file chmod shebang).each do |method|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)
            @generator.send(:#{method}, *args, &block)
          end
        RUBY
      end

      # TODO: Remove once this is fully in place
      def method_missing(meth, *args, &block)
        STDERR.puts "Calling #{meth} with #{args.inspect} with #{block}"
        @generator.send(meth, *args, &block)
      end
  end

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
      template "config/databases/#{@options[:database]}.yml", "config/database.yml"
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
      unless options[:skip_prototype]
        directory "public/javascripts"
      else
        empty_directory_with_gitkeep "public/javascripts"
        create_file "public/javascripts/application.js"
      end
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

    class AppGenerator < Base
      DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db )

      attr_accessor :rails_template
      add_shebang_option!

      argument :app_path,               :type => :string

      class_option :database,           :type => :string, :aliases => "-d", :default => "sqlite3",
                                        :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

      class_option :builder,            :type => :string, :aliases => "-b",
                                        :desc => "Path to an application builder (can be a filesystem path or URL)"

      class_option :template,           :type => :string, :aliases => "-m",
                                        :desc => "Path to an application template (can be a filesystem path or URL)"

      class_option :dev,                :type => :boolean, :default => false,
                                        :desc => "Setup the application with Gemfile pointing to your Rails checkout"

      class_option :edge,               :type => :boolean, :default => false,
                                        :desc => "Setup the application with Gemfile pointing to Rails repository"

      class_option :skip_gemfile,       :type => :boolean, :default => false,
                                        :desc => "Don't create a Gemfile"

      class_option :skip_active_record, :type => :boolean, :aliases => "-O", :default => false,
                                        :desc => "Skip Active Record files"

      class_option :skip_test_unit,     :type => :boolean, :aliases => "-T", :default => false,
                                        :desc => "Skip Test::Unit files"

      class_option :skip_prototype,     :type => :boolean, :aliases => "-J", :default => false,
                                        :desc => "Skip Prototype files"

      class_option :skip_git,           :type => :boolean, :aliases => "-G", :default => false,
                                        :desc => "Skip Git ignores and keeps"

      # Add bin/rails options
      class_option :version,            :type => :boolean, :aliases => "-v", :group => :rails,
                                        :desc => "Show Rails version number and quit"

      class_option :help,               :type => :boolean, :aliases => "-h", :group => :rails,
                                        :desc => "Show this help message and quit"

      def initialize(*args)
        raise Error, "Options should be given after the application name. For details run: rails --help" if args[0].blank?

        @original_wd = Dir.pwd

        super

        if !options[:skip_active_record] && !DATABASES.include?(options[:database])
          raise Error, "Invalid value for --database option. Supported for preconfiguration are: #{DATABASES.join(", ")}."
        end
      end

      def create_root
        self.destination_root = File.expand_path(app_path, destination_root)
        valid_app_const?

        empty_directory '.'
        set_default_accessors!
        FileUtils.cd(destination_root)
      end

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

      def create_prototype_files
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

      def apply_rails_template
        apply rails_template if rails_template
      rescue Thor::Error, LoadError, Errno::ENOENT => e
        raise Error, "The template [#{rails_template}] could not be loaded. Error: #{e}"
      end

      def bundle_if_dev_or_edge
        bundle_command = File.basename(Thor::Util.ruby_command).sub(/ruby/, 'bundle')
        run "#{bundle_command} install" if dev_or_edge?
      end

    protected

      def self.banner
        "rails new #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      def builder
        @builder ||= begin
          if path = options[:builder]
            if URI(path).is_a?(URI::HTTP)
              contents = open(path, "Accept" => "application/x-thor-template") {|io| io.read }
            else
              contents = open(File.expand_path(path, @original_wd)) {|io| io.read }
            end

            prok = eval("proc { #{contents} }", TOPLEVEL_BINDING, path, 1)
            instance_eval(&prok)
          end

          builder_class = defined?(::AppBuilder) ? ::AppBuilder : Rails::AppBuilder
          builder_class.send(:include, ActionMethods)
          builder_class.new(self)
        end
      end

      def build(meth, *args)
        builder.send(meth, *args) if builder.respond_to?(meth)
      end

      def set_default_accessors!
        self.rails_template = case options[:template]
          when /^http:\/\//
            options[:template]
          when String
            File.expand_path(options[:template], Dir.pwd)
          else
            options[:template]
        end
      end

      # Define file as an alias to create_file for backwards compatibility.
      def file(*args, &block)
        create_file(*args, &block)
      end

      def app_name
        @app_name ||= File.basename(destination_root)
      end

      def app_const_base
        @app_const_base ||= app_name.gsub(/\W/, '_').squeeze('_').camelize
      end

      def app_const
        @app_const ||= "#{app_const_base}::Application"
      end

      def valid_app_const?
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

      def dev_or_edge?
        options.dev? || options.edge?
      end

      def gem_for_database
        # %w( mysql oracle postgresql sqlite3 frontbase ibm_db )
        case options[:database]
        when "oracle"     then "ruby-oci8"
        when "postgresql" then "pg"
        when "sqlite3"    then "sqlite3-ruby"
        when "frontbase"  then "ruby-frontbase"
        else options[:database]
        end
      end

      def require_for_database
        case options[:database]
        when "sqlite3" then "sqlite3"
        end
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
        ].find { |f| File.exist?(f) } unless Config::CONFIG['host_os'] =~ /mswin|mingw/
      end

      def empty_directory_with_gitkeep(destination, config = {})
        empty_directory(destination, config)
        create_file("#{destination}/.gitkeep") unless options[:skip_git]
      end
    end
  end
end
