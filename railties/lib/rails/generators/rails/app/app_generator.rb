# frozen_string_literal: true

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
  #
  #  class CustomAppBuilder < Rails::AppBuilder
  #    def test
  #      @generator.gem "rspec-rails", group: [:development, :test]
  #      run "bundle install"
  #      generate "rspec:install"
  #    end
  #  end
  class AppBuilder
    def rakefile
      template "Rakefile"
    end

    def readme
      copy_file "README.md", "README.md"
    end

    def ruby_version
      template "ruby-version", ".ruby-version"
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

    def gitattributes
      template "gitattributes", ".gitattributes"
    end

    def version_control
      if !options[:skip_git] && !options[:pretend]
        run "git init", capture: options[:quiet], abort_on_failure: false
      end
    end

    def package_json
      template "package.json"
    end

    def app
      directory "app"

      empty_directory_with_keep_file "app/assets/images"

      keep_file  "app/controllers/concerns"
      keep_file  "app/models/concerns"
    end

    def bin
      directory "bin" do |content|
        "#{shebang}\n" + content
      end
      chmod "bin", 0755 & ~File.umask, verbose: false

      remove_file "bin/spring" unless spring_install?
      remove_file "bin/yarn" if options[:skip_javascript]
    end

    def bin_when_updating
      bin
    end

    def yarn_when_updating
      return if File.exist?("bin/yarn")

      template "bin/yarn" do |content|
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
        template "cable.yml" unless options[:skip_action_cable]
        template "puma.rb"   unless options[:skip_puma]
        template "spring.rb" if spring_install?
        template "storage.yml" unless skip_active_storage?

        directory "environments"
        directory "initializers"
        directory "locales"
      end
    end

    def config_when_updating
      cookie_serializer_config_exist = File.exist?("config/initializers/cookies_serializer.rb")
      action_cable_config_exist      = File.exist?("config/cable.yml")
      active_storage_config_exist    = File.exist?("config/storage.yml")
      rack_cors_config_exist         = File.exist?("config/initializers/cors.rb")
      assets_config_exist            = File.exist?("config/initializers/assets.rb")
      asset_manifest_exist          = File.exist?("app/assets/config/manifest.js")
      asset_app_stylesheet_exist    = File.exist?("app/assets/stylesheets/application.css")
      csp_config_exist = File.exist?("config/initializers/content_security_policy.rb")
      permissions_policy_config_exist = File.exist?("config/initializers/permissions_policy.rb")

      @config_target_version = Rails.application.config.loaded_config_version || "5.0"

      config
      configru

      unless cookie_serializer_config_exist
        gsub_file "config/initializers/cookies_serializer.rb", /json(?!,)/, "marshal"
      end

      if !options[:skip_action_cable] && !action_cable_config_exist
        template "config/cable.yml"
      end

      if !skip_active_storage? && !active_storage_config_exist
        template "config/storage.yml"
      end

      if options[:skip_sprockets] && !assets_config_exist
        remove_file "config/initializers/assets.rb"
      end

      if options[:skip_sprockets] && !asset_manifest_exist
        remove_file "app/assets/config/manifest.js"
      end

      if options[:skip_sprockets] && !asset_app_stylesheet_exist
        remove_file "app/assets/stylesheets/application.css"
      end

      unless rack_cors_config_exist
        remove_file "config/initializers/cors.rb"
      end

      if options[:api]
        unless cookie_serializer_config_exist
          remove_file "config/initializers/cookies_serializer.rb"
        end

        unless csp_config_exist
          remove_file "config/initializers/content_security_policy.rb"
        end

        unless permissions_policy_config_exist
          remove_file "config/initializers/permissions_policy.rb"
        end
      end
    end

    def master_key
      return if options[:pretend] || options[:dummy_app]

      require "rails/generators/rails/master_key/master_key_generator"
      master_key_generator = Rails::Generators::MasterKeyGenerator.new([], quiet: options[:quiet], force: options[:force])
      master_key_generator.add_master_key_file_silently
      master_key_generator.ignore_master_key_file_silently
    end

    def credentials
      return if options[:pretend] || options[:dummy_app]

      require "rails/generators/rails/credentials/credentials_generator"
      Rails::Generators::CredentialsGenerator.new([], quiet: options[:quiet]).add_credentials_file_silently
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

    def storage
      empty_directory_with_keep_file "storage"
      empty_directory_with_keep_file "tmp/storage"
    end

    def test
      empty_directory_with_keep_file "test/fixtures/files"
      empty_directory_with_keep_file "test/controllers"
      empty_directory_with_keep_file "test/mailers"
      empty_directory_with_keep_file "test/models"
      empty_directory_with_keep_file "test/helpers"
      empty_directory_with_keep_file "test/integration"

      template "test/channels/application_cable/connection_test.rb"
      template "test/test_helper.rb"
    end

    def system_test
      empty_directory_with_keep_file "test/system"

      template "test/application_system_test_case.rb"
    end

    def tmp
      empty_directory_with_keep_file "tmp"
      empty_directory_with_keep_file "tmp/pids"
      empty_directory "tmp/cache"
      empty_directory "tmp/cache/assets"
    end

    def vendor
      empty_directory_with_keep_file "vendor"
    end

    def config_target_version
      defined?(@config_target_version) ? @config_target_version : Rails::VERSION::STRING.to_f
    end
  end

  module Generators
    # We need to store the RAILS_DEV_PATH in a constant, otherwise the path
    # can change in Ruby 1.8.7 when we FileUtils.cd.
    RAILS_DEV_PATH = File.expand_path("../../../../../..", __dir__)

    class AppGenerator < AppBase
      # :stopdoc:

      WEBPACKS = %w( react vue angular elm stimulus )

      add_shared_options_for "application"

      # Add rails command options
      class_option :version, type: :boolean, aliases: "-v", group: :rails,
                             desc: "Show Rails version number and quit"

      class_option :api, type: :boolean,
                         desc: "Preconfigure smaller stack for API only apps"

      class_option :minimal, type: :boolean,
                             desc: "Preconfigure a minimal rails app"

      class_option :skip_bundle, type: :boolean, aliases: "-B", default: false,
                                 desc: "Don't run bundle install"

      class_option :webpack, type: :string, aliases: "--webpacker", default: nil,
                             desc: "Preconfigure Webpack with a particular framework (options: #{WEBPACKS.join(", ")})"

      class_option :skip_webpack_install, type: :boolean, default: false,
                                          desc: "Don't run Webpack install"

      def initialize(*args)
        super

        if !options[:skip_active_record] && !DATABASES.include?(options[:database])
          raise Error, "Invalid value for --database option. Supported preconfigurations are: #{DATABASES.join(", ")}."
        end

        # Force sprockets and yarn to be skipped when generating API only apps.
        # Can't modify options hash as it's frozen by default.
        if options[:api]
          self.options = options.merge(skip_sprockets: true, skip_javascript: true).freeze
        end

        if options[:minimal]
          self.options = options.merge(
            skip_action_cable: true,
            skip_action_mailer: true,
            skip_action_mailbox: true,
            skip_action_text: true,
            skip_active_job: true,
            skip_active_storage: true,
            skip_bootsnap: true,
            skip_dev_gems: true,
            skip_javascript: true,
            skip_jbuilder: true,
            skip_spring: true,
            skip_system_test: true,
            skip_webpack_install: true,
            skip_turbolinks: true).tap do |option|
              if option[:webpack]
                option[:skip_webpack_install] = false
                option[:skip_javascript] = false
              end
            end.freeze
        end

        @after_bundle_callbacks = []
      end

      public_task :set_default_accessors!
      public_task :create_root

      def create_root_files
        build(:readme)
        build(:rakefile)
        build(:ruby_version)
        build(:configru)

        unless options[:skip_git]
          build(:gitignore)
          build(:gitattributes)
        end

        build(:gemfile) unless options[:skip_gemfile]
        build(:version_control)
        build(:package_json) unless options[:skip_javascript]
      end

      def create_app_files
        build(:app)
      end

      def create_bin_files
        build(:bin)
      end

      def update_bin_files
        build(:bin_when_updating)
      end
      remove_task :update_bin_files

      def update_bin_yarn
        build(:yarn_when_updating)
      end
      remove_task :update_bin_yarn

      def update_active_storage
        unless skip_active_storage?
          rails_command "active_storage:update", inline: true
        end
      end
      remove_task :update_active_storage

      def create_config_files
        build(:config)
      end

      def update_config_files
        build(:config_when_updating)
      end
      remove_task :update_config_files

      def create_master_key
        build(:master_key)
      end

      def create_credentials
        build(:credentials)
      end

      def display_upgrade_guide_info
        say "\nAfter this, check Rails upgrade guide at https://guides.rubyonrails.org/upgrading_ruby_on_rails.html for more details about upgrading your app."
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
        return if options[:skip_active_record]
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

      def create_tmp_files
        build(:tmp)
      end

      def create_vendor_files
        build(:vendor)
      end

      def create_test_files
        build(:test) unless options[:skip_test]
      end

      def create_system_test_files
        build(:system_test) if depends_on_system_test?
      end

      def create_storage_files
        build(:storage) unless skip_active_storage?
      end

      def delete_app_assets_if_api_option
        if options[:api]
          remove_dir "app/assets"
          remove_dir "lib/assets"
          remove_dir "tmp/cache/assets"
        end
      end

      def delete_app_helpers_if_api_option
        if options[:api]
          remove_dir "app/helpers"
          remove_dir "test/helpers"
        end
      end

      def delete_app_views_if_api_option
        if options[:api]
          if options[:skip_action_mailer]
            remove_dir "app/views"
          else
            remove_file "app/views/layouts/application.html.erb"
          end
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
        if options[:skip_javascript] && !options[:minimal]
          remove_dir "app/javascript"
        end
      end

      def delete_js_packs_when_minimal_skipping_webpack
        if options[:minimal] && options[:skip_webpack_install]
          remove_dir "app/javascript/packs"
          keep_file  "app/javascript"
        end
      end

      def delete_assets_initializer_skipping_sprockets
        if options[:skip_sprockets]
          remove_file "config/initializers/assets.rb"
          remove_file "app/assets/config/manifest.js"
          remove_file "app/assets/stylesheets/application.css"
        end
      end

      def delete_application_record_skipping_active_record
        if options[:skip_active_record]
          remove_file "app/models/application_record.rb"
        end
      end

      def delete_active_job_folder_if_skipping_active_job
        if options[:skip_active_job]
          remove_dir "app/jobs"
        end
      end

      def delete_action_mailer_files_skipping_action_mailer
        if options[:skip_action_mailer]
          remove_file "app/views/layouts/mailer.html.erb"
          remove_file "app/views/layouts/mailer.text.erb"
          remove_dir "app/mailers"
          remove_dir "test/mailers"
        end
      end

      def delete_action_cable_files_skipping_action_cable
        if options[:skip_action_cable]
          remove_dir "app/javascript/channels"
          remove_dir "app/channels"
          remove_dir "test/channels"
        end
      end

      def delete_non_api_initializers_if_api_option
        if options[:api]
          remove_file "config/initializers/cookies_serializer.rb"
          remove_file "config/initializers/content_security_policy.rb"
          remove_file "config/initializers/permissions_policy.rb"
        end
      end

      def delete_api_initializers
        unless options[:api]
          remove_file "config/initializers/cors.rb"
        end
      end

      def delete_new_framework_defaults
        unless options[:update]
          remove_file "config/initializers/new_framework_defaults_6_2.rb"
        end
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template, :run_bundle
      public_task :generate_bundler_binstub
      public_task :run_webpack

      def run_after_bundle_callbacks
        @after_bundle_callbacks.each(&:call)
      end

      def self.banner
        "rails new #{arguments.map(&:usage).join(' ')} [options]"
      end

    # :startdoc:

    private
      # Define file as an alias to create_file for backwards compatibility.
      def file(*args, &block)
        create_file(*args, &block)
      end

      # Registers a callback to be executed after bundle and spring binstubs
      # have run.
      #
      #   after_bundle do
      #     git add: '.'
      #   end
      def after_bundle(&block) # :doc:
        @after_bundle_callbacks << block
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
        xdg_config_home = ENV["XDG_CONFIG_HOME"].presence || "~/.config"
        xdg_railsrc = File.expand_path("rails/railsrc", xdg_config_home)
        if File.exist?(xdg_railsrc)
          xdg_railsrc
        else
          File.expand_path("~/.railsrc")
        end
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
          if (customrc = argv.index { |x| x.include?("--rc=") })
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
