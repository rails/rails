require "rails/generators/app_base"

module Rails
  module ActionMethods # :nodoc:
    attr_reader :options

    def initialize(generator)
      @generator = generator
      @options   = generator.options
    end

    private
      %w(template copy_file directory empty_directory inside
         empty_directory_with_keep_file create_file chmod shebang).each do |method|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)
            @generator.send(:#{method}, *args, &block)
          end
        RUBY
      end

      # TODO: Remove once this is fully in place
      def method_missing(meth, *args, &block)
        @generator.send(meth, *args, &block)
      end
  end

  # The application builder allows you to override elements of the application
  # generator without being forced to reverse the operations of the default
  # generator.
  #
  # This allows you to override entire operations, like the creation of the
  # Gemfile, README, or JavaScript files, without needing to know exactly
  # what those operations do so you can create another template action.
  class AppBuilder
    def rakefile
      template "Rakefile"
    end

    def readme
      copy_file "README.md", "README.md"
    end

    def gemfile
      template "Gemfile"
    end

    def configru
      template "config.ru"
    end

    def gitignore
      template "gitignore", ".gitignore"
    end

    def app
      directory "app"

      keep_file  "app/assets/images"
      empty_directory_with_keep_file "app/assets/javascripts/channels" unless options[:skip_action_cable]

      keep_file  "app/controllers/concerns"
      keep_file  "app/models/concerns"
    end

    def bin
      directory "bin" do |content|
        "#{shebang}\n" + content
      end
      chmod "bin", 0755 & ~File.umask, verbose: false
    end

    def config
      empty_directory "config"

      inside "config" do
        template "routes.rb"
        template "application.rb"
        template "environment.rb"
        template "secrets.yml"
        template "cable.yml" unless options[:skip_action_cable]
        template "puma.rb"   unless options[:skip_puma]
        template "spring.rb" if spring_install?

        directory "environments"
        directory "initializers"
        directory "locales"
      end
    end

    def config_when_updating
      cookie_serializer_config_exist = File.exist?("config/initializers/cookies_serializer.rb")
      action_cable_config_exist = File.exist?("config/cable.yml")
      rack_cors_config_exist = File.exist?("config/initializers/cors.rb")

      config

      gsub_file "config/environments/development.rb", /^(\s+)config\.file_watcher/, '\1# config.file_watcher'

      unless cookie_serializer_config_exist
        gsub_file "config/initializers/cookies_serializer.rb", /json(?!,)/, "marshal"
      end

      unless action_cable_config_exist
        template "config/cable.yml"
      end

      unless rack_cors_config_exist
        remove_file "config/initializers/cors.rb"
      end
    end

    def database_yml
      template "config/databases/#{options[:database]}.yml", "config/database.yml"
    end

    def db
      directory "db"
    end

    def lib
      empty_directory "lib"
      empty_directory_with_keep_file "lib/tasks"
      empty_directory_with_keep_file "lib/assets"
    end

    def log
      empty_directory_with_keep_file "log"
    end

    def public_directory
      directory "public", "public", recursive: false
    end

    def test
      empty_directory_with_keep_file "test/fixtures"
      empty_directory_with_keep_file "test/fixtures/files"
      empty_directory_with_keep_file "test/controllers"
      empty_directory_with_keep_file "test/mailers"
      empty_directory_with_keep_file "test/models"
      empty_directory_with_keep_file "test/helpers"
      empty_directory_with_keep_file "test/integration"

      template "test/test_helper.rb"
    end

    def tmp
      empty_directory_with_keep_file "tmp"
      empty_directory "tmp/cache"
      empty_directory "tmp/cache/assets"
    end

    def vendor
      vendor_javascripts
      vendor_stylesheets
    end

    def vendor_javascripts
      unless options[:skip_javascript]
        empty_directory_with_keep_file "vendor/assets/javascripts"
      end
    end

    def vendor_stylesheets
      empty_directory_with_keep_file "vendor/assets/stylesheets"
    end
  end

  module Generators
    # We need to store the RAILS_DEV_PATH in a constant, otherwise the path
    # can change in Ruby 1.8.7 when we FileUtils.cd.
    RAILS_DEV_PATH = File.expand_path("../../../../../..", File.dirname(__FILE__))
    RESERVED_NAMES = %w[application destroy plugin runner test]

    class AppGenerator < AppBase # :nodoc:
      add_shared_options_for "application"

      # Add bin/rails options
      class_option :version, type: :boolean, aliases: "-v", group: :rails,
                             desc: "Show Rails version number and quit"

      class_option :api, type: :boolean,
                         desc: "Preconfigure smaller stack for API only apps"

      def initialize(*args)
        super

        unless app_path
          raise Error, "Application name should be provided in arguments. For details run: rails --help"
        end

        if !options[:skip_active_record] && !DATABASES.include?(options[:database])
          raise Error, "Invalid value for --database option. Supported for preconfiguration are: #{DATABASES.join(", ")}."
        end

        # Force sprockets to be skipped when generating API only apps.
        # Can't modify options hash as it's frozen by default.
        self.options = options.merge(skip_sprockets: true, skip_javascript: true).freeze if options[:api]
      end

      public_task :set_default_accessors!
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

      def create_bin_files
        build(:bin)
      end

      def create_config_files
        build(:config)
      end

      def update_config_files
        build(:config_when_updating)
      end
      remove_task :update_config_files

      def display_upgrade_guide_info
        say "\nAfter this, check Rails upgrade guide at http://guides.rubyonrails.org/upgrading_ruby_on_rails.html for more details about upgrading your app."
      end
      remove_task :display_upgrade_guide_info

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

      def create_lib_files
        build(:lib)
      end

      def create_log_files
        build(:log)
      end

      def create_public_files
        build(:public_directory)
      end

      def create_test_files
        build(:test) unless options[:skip_test]
      end

      def create_tmp_files
        build(:tmp)
      end

      def create_vendor_files
        build(:vendor)
      end

      def delete_app_assets_if_api_option
        if options[:api]
          remove_dir "app/assets"
          remove_dir "lib/assets"
          remove_dir "tmp/cache/assets"
          remove_dir "vendor/assets"
        end
      end

      def delete_app_helpers_if_api_option
        if options[:api]
          remove_dir "app/helpers"
          remove_dir "test/helpers"
        end
      end

      def delete_application_layout_file_if_api_option
        if options[:api]
          remove_file "app/views/layouts/application.html.erb"
        end
      end

      def delete_public_files_if_api_option
        if options[:api]
          remove_file "public/404.html"
          remove_file "public/422.html"
          remove_file "public/500.html"
          remove_file "public/apple-touch-icon-precomposed.png"
          remove_file "public/apple-touch-icon.png"
          remove_file "public/favicon.ico"
        end
      end

      def delete_js_folder_skipping_javascript
        if options[:skip_javascript]
          remove_dir "app/assets/javascripts"
        end
      end

      def delete_assets_initializer_skipping_sprockets
        if options[:skip_sprockets]
          remove_file "config/initializers/assets.rb"
        end
      end

      def delete_application_record_skipping_active_record
        if options[:skip_active_record]
          remove_file "app/models/application_record.rb"
        end
      end

      def delete_action_mailer_files_skipping_action_mailer
        if options[:skip_action_mailer]
          remove_file "app/mailers/application_mailer.rb"
          remove_file "app/views/layouts/mailer.html.erb"
          remove_file "app/views/layouts/mailer.text.erb"
        end
      end

      def delete_action_cable_files_skipping_action_cable
        if options[:skip_action_cable]
          remove_file "config/cable.yml"
          remove_file "app/assets/javascripts/cable.js"
          remove_dir "app/channels"
        end
      end

      def delete_non_api_initializers_if_api_option
        if options[:api]
          remove_file "config/initializers/cookies_serializer.rb"
        end
      end

      def delete_api_initializers
        unless options[:api]
          remove_file "config/initializers/cors.rb"
        end
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template, :run_bundle
      public_task :generate_spring_binstubs

      def run_after_bundle_callbacks
        @after_bundle_callbacks.each(&:call)
      end

    protected

      def self.banner
        "rails new #{arguments.map(&:usage).join(' ')} [options]"
      end

      # Define file as an alias to create_file for backwards compatibility.
      def file(*args, &block)
        create_file(*args, &block)
      end

      def app_name
        @app_name ||= (defined_app_const_base? ? defined_app_name : File.basename(destination_root)).tr('\\', "").tr(". ", "_")
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
        @app_const_base ||= defined_app_const_base || app_name.gsub(/\W/, "_").squeeze("_").camelize
      end
      alias :camelized :app_const_base

      def app_const
        @app_const ||= "#{app_const_base}::Application"
      end

      def valid_const?
        if app_const =~ /^\d/
          raise Error, "Invalid application name #{app_name}. Please give a name which does not start with numbers."
        elsif RESERVED_NAMES.include?(app_name)
          raise Error, "Invalid application name #{app_name}. Please give a " \
                       "name which does not match one of the reserved rails " \
                       "words: #{RESERVED_NAMES.join(", ")}"
        elsif Object.const_defined?(app_const_base)
          raise Error, "Invalid application name #{app_name}, constant #{app_const_base} is already in use. Please choose another application name."
        end
      end

      def app_secret
        SecureRandom.hex(64)
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
        ].find { |f| File.exist?(f) } unless RbConfig::CONFIG["host_os"] =~ /mswin|mingw/
      end

      def get_builder_class
        defined?(::AppBuilder) ? ::AppBuilder : Rails::AppBuilder
      end
    end

    # This class handles preparation of the arguments before the AppGenerator is
    # called. The class provides version or help information if they were
    # requested, and also constructs the railsrc file (used for extra configuration
    # options).
    #
    # This class should be called before the AppGenerator is required and started
    # since it configures and mutates ARGV correctly.
    class ARGVScrubber # :nodoc:
      def initialize(argv = ARGV)
        @argv = argv
      end

      def prepare!
        handle_version_request!(@argv.first)
        handle_invalid_command!(@argv.first, @argv) do
          handle_rails_rc!(@argv.drop(1))
        end
      end

      def self.default_rc_file
        File.expand_path("~/.railsrc")
      end

      private

        def handle_version_request!(argument)
          if ["--version", "-v"].include?(argument)
            require "rails/version"
            puts "Rails #{Rails::VERSION::STRING}"
            exit(0)
          end
        end

        def handle_invalid_command!(argument, argv)
          if argument == "new"
            yield
          else
            ["--help"] + argv.drop(1)
          end
        end

        def handle_rails_rc!(argv)
          if argv.find { |arg| arg == "--no-rc" }
            argv.reject { |arg| arg == "--no-rc" }
          else
            railsrc(argv) { |rc_argv, rc| insert_railsrc_into_argv!(rc_argv, rc) }
          end
        end

        def railsrc(argv)
          if (customrc = argv.index{ |x| x.include?("--rc=") })
            fname = File.expand_path(argv[customrc].gsub(/--rc=/, ""))
            yield(argv.take(customrc) + argv.drop(customrc + 1), fname)
          else
            yield argv, self.class.default_rc_file
          end
        end

        def read_rc_file(railsrc)
          extra_args = File.readlines(railsrc).flat_map(&:split)
          puts "Using #{extra_args.join(" ")} from #{railsrc}"
          extra_args
        end

        def insert_railsrc_into_argv!(argv, railsrc)
          return argv unless File.exist?(railsrc)
          extra_args = read_rc_file railsrc
          argv.take(1) + extra_args + argv.drop(1)
        end
    end
  end
end
