require File.dirname(__FILE__) + '/../base'
require 'rbconfig'
require 'digest/md5' 
require 'active_support/secure_random'
require 'rails/version'

module Rails::Generators
  class App < Base
    DEFAULT_SHEBANG  = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
    DATABASES        = %w( mysql oracle postgresql sqlite2 sqlite3 frontbase ibm_db )
    DEFAULT_DATABASE = 'sqlite3'

    argument :app_path, :type => :string

    class_option :ruby, :type => :string, :aliases => "-d", :default => DEFAULT_SHEBANG,
                        :desc => "Path to the Ruby binary of your choice"

    class_option :database, :type => :string, :aliases => "-d", :default => DEFAULT_DATABASE,
                            :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

    class_option :with_dispatchers, :type => :boolean, :aliases => "-D", :default => false,
                                    :desc => "Add CGI/FastCGI/mod_ruby dispatchers code"

    class_option :freeze, :type => :boolean, :aliases => "-f", :default => false,
                          :desc => "Freeze Rails in vendor/rails from the gems"

    class_option :template, :type => :string, :aliases => "-m",
                            :desc => "Use an application template that lives at path (can be a filesystem path or URL)."

    def create_root
      self.root = File.expand_path(app_path, root)
      empty_directory '.'

      app_name # Sets the app name
      FileUtils.cd(root)
    end

    def create_root_files
      copy_file "Rakefile"
      copy_file "README"
    end

    def create_app_files
      directory "app"
    end

    def create_config_files
      empty_directory "config"

      inside "config" do
        copy_file "boot.rb"
        copy_file "routes.rb"

        template "databases/#{options[:database]}.yml", "database.yml"
        template "environment.rb"

        directory "environments"
        directory "initializers"
        directory "locales"
      end
    end

    def create_db_files
      directory "db"
    end

    def create_doc_files
      directory "doc"
    end

    def create_lib_files
      empty_directory "lib"
      empty_directory "lib/tasks"
    end

    def create_log_files
      empty_directory "log"

      inside "log" do
        %w( server production development test ).each do |file|
          create_file "#{file}.log"
          chmod "#{file}.log", 0666, false
        end
      end
    end

    def create_public_files
      directory "public"
    end

    def create_dispatch_files
      return unless options.with_dispatchers?

      copy_file "dispatchers/config.ru", "config.ru"

      template "dispatchers/dispatch.rb", "public/dispatch.rb"
      chmod "public/dispatch.rb", 0755, false

      template "dispatchers/dispatch.rb", "public/dispatch.cgi"
      chmod "public/dispatch.cgi", 0755, false

      template "dispatchers/dispatch.fcgi", "public/dispatch.fcgi"
      chmod "public/dispatch.fcgi", 0755, false
    end

    def create_javascript_files
      directory "javascripts/prototype", "public/javascripts"
    end

    def create_script_files
      directory "script"
      chmod "script", 0755, false
    end

    def create_test_files
      directory "test"
    end

    def create_tmp_files
      empty_directory "tmp"

      inside "tmp" do
        %w(sessions sockets cache pids).each do |dir|
          empty_directory dir
        end
      end
    end

    def create_vendor_files
      empty_directory "vendor/plugins"
    end

    protected

      def app_name
        @app_name ||= File.basename(root)
      end

      def app_secret
        ActiveSupport::SecureRandom.hex(64)
      end

      def freeze
        options[:freeze]
      end

      def shebang
        options[:ruby] || "#!/usr/bin/env ruby"
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
        ].find { |f| File.exist?(f) } unless RUBY_PLATFORM =~ /(:?mswin|mingw)/
      end
  end
end
