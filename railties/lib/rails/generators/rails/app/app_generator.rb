# frozen_string_literal: true

require "rails/generators/app_base"
require "rails/generators/rails/devcontainer/devcontainer_generator"

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
          def #{method}(...)
            @generator.send(:#{method}, ...)
          end
        RUBY
      end

      def method_missing(...)
        @generator.send(...)
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

    def node_version
      template "node-version", ".node-version"
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

    def dockerfiles
      template "Dockerfile"
      template "dockerignore", ".dockerignore"

      template "docker-entrypoint", "bin/docker-entrypoint"
      chmod "bin/docker-entrypoint", 0755 & ~File.umask, verbose: false
    end

    def cifiles
      empty_directory ".github/workflows"
      template "github/ci.yml", ".github/workflows/ci.yml"
      template "github/dependabot.yml", ".github/dependabot.yml"
    end

    def rubocop
      template "rubocop.yml", ".rubocop.yml"
    end

    def version_control
      if !options[:skip_git] && !options[:pretend]
        run git_init_command, capture: options[:quiet], abort_on_failure: false
      end
    end

    def app
      directory "app"

      empty_directory_with_keep_file "app/assets/images"

      keep_file  "app/controllers/concerns"
      keep_file  "app/models/concerns"
    end

    def bin
      exclude_pattern = Regexp.union([(/thrust/ if skip_thruster?), (/rubocop/ if skip_rubocop?), (/brakeman/ if skip_brakeman?)].compact)
      directory "bin", { exclude_pattern: exclude_pattern } do |content|
        "#{shebang}\n" + content
      end
      chmod "bin", 0755 & ~File.umask, verbose: false
    end

    def bin_when_updating
      bin
    end

    def config
      empty_directory "config"

      inside "config" do
        template "routes.rb" unless options[:update]
        template "application.rb"
        template "environment.rb"
        template "cable.yml" unless options[:update] || options[:skip_action_cable]
        template "puma.rb"
        template "storage.yml" unless options[:update] || skip_active_storage?

        directory "environments"
        directory "initializers"
        directory "locales" unless options[:update]
      end
    end

    def config_when_updating
      action_cable_config_exist       = File.exist?("config/cable.yml")
      active_storage_config_exist     = File.exist?("config/storage.yml")
      rack_cors_config_exist          = File.exist?("config/initializers/cors.rb")
      assets_config_exist             = File.exist?("config/initializers/assets.rb")
      asset_app_stylesheet_exist      = File.exist?("app/assets/stylesheets/application.css")
      csp_config_exist                = File.exist?("config/initializers/content_security_policy.rb")

      @config_target_version = Rails.application.config.loaded_config_version || "5.0"

      config

      if !options[:skip_action_cable] && !action_cable_config_exist
        template "config/cable.yml"
      end

      if !skip_active_storage? && !active_storage_config_exist
        template "config/storage.yml"
      end

      if skip_asset_pipeline? && !assets_config_exist
        remove_file "config/initializers/assets.rb"
      end

      if skip_asset_pipeline? && !asset_app_stylesheet_exist
        remove_file "app/assets/stylesheets/application.css"
      end

      unless rack_cors_config_exist
        remove_file "config/initializers/cors.rb"
      end

      if options[:api]
        unless csp_config_exist
          remove_file "config/initializers/content_security_policy.rb"
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
      Rails::Generators::CredentialsGenerator.new([], quiet: true).add_credentials_file
    end

    def credentials_diff_enroll
      return if options[:skip_decrypted_diffs] || options[:dummy_app] || options[:pretend]

      @generator.shell.mute do
        rails_command "credentials:diff --enroll", inline: true, shell: @generator.shell
      end
    end

    def database_yml
      template database.template, "config/database.yml"
    end

    def db
      directory "db"
    end

    def lib
      empty_directory "lib"
      empty_directory_with_keep_file "lib/tasks"
    end

    def log
      empty_directory_with_keep_file "log"
    end

    def public_directory
      return if options[:update] && options[:api]

      directory "public", "public", recursive: false
    end

    def script
      empty_directory_with_keep_file "script"
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

      template "test/test_helper.rb"
    end

    def system_test
      empty_directory_with_keep_file "test/system"

      template "test/application_system_test_case.rb"
    end

    def tmp
      empty_directory_with_keep_file "tmp"
      empty_directory_with_keep_file "tmp/pids"
    end

    def vendor
      empty_directory_with_keep_file "vendor"
    end

    def config_target_version
      @config_target_version || Rails::VERSION::STRING.to_f
    end

    def devcontainer
      devcontainer_options = {
        database: options[:database],
        redis: options[:skip_solid] && !(options[:skip_action_cable] && options[:skip_active_job]),
        kamal: !options[:skip_kamal],
        system_test: depends_on_system_test?,
        active_storage: !options[:skip_active_storage],
        dev: options[:dev],
        node: using_node?,
        app_name: app_name,
        skip_solid: options[:skip_solid]
      }

      Rails::Generators::DevcontainerGenerator.new([], devcontainer_options).invoke_all
    end
  end

  module Generators
    class AppGenerator < AppBase
      # :stopdoc:

      add_shared_options_for "application"

      # Add rails command options
      class_option :version, type: :boolean, aliases: "-v", group: :rails, desc: "Show Rails version number and quit"
      class_option :api, type: :boolean, desc: "Preconfigure smaller stack for API only apps"
      class_option :minimal, type: :boolean, desc: "Preconfigure a minimal rails app"
      class_option :javascript, type: :string, aliases: ["-j", "--js"], default: "importmap", enum: JAVASCRIPT_OPTIONS, desc: "Choose JavaScript approach"
      class_option :css, type: :string, aliases: "-c", enum: CSS_OPTIONS, desc: "Choose CSS processor. Check https://github.com/rails/cssbundling-rails for more options"
      class_option :skip_bundle, type: :boolean, aliases: "-B", default: nil, desc: "Don't run bundle install"
      class_option :skip_decrypted_diffs, type: :boolean, default: nil, desc: "Don't configure git to show decrypted diffs of encrypted credentials"

      OPTION_IMPLICATIONS = # :nodoc:
        AppBase::OPTION_IMPLICATIONS.merge(
          skip_git: [:skip_decrypted_diffs],
          minimal: [
            :skip_action_cable,
            :skip_action_mailbox,
            :skip_action_mailer,
            :skip_action_text,
            :skip_active_job,
            :skip_active_storage,
            :skip_bootsnap,
            :skip_brakeman,
            :skip_ci,
            :skip_dev_gems,
            :skip_docker,
            :skip_hotwire,
            :skip_javascript,
            :skip_jbuilder,
            :skip_kamal,
            :skip_rubocop,
            :skip_solid,
            :skip_system_test,
            :skip_thruster
          ],
          api: [
            :skip_asset_pipeline,
            :skip_javascript,
          ],
        ) do |option, implications, more_implications|
          implications + more_implications
        end

      META_OPTIONS = [:minimal] # :nodoc:

      def self.apply_rails_template(template, destination) # :nodoc:
        generator = new([destination], { template: template }, { destination_root: destination })
        generator.set_default_accessors!
        generator.apply_rails_template
        generator.run_bundle
        generator.run_after_bundle_callbacks
      end

      def initialize(*args)
        super

        imply_options(OPTION_IMPLICATIONS, meta_options: META_OPTIONS)

        @after_bundle_callbacks = []
      end

      public_task :report_implied_options
      public_task :set_default_accessors!
      public_task :create_root
      public_task :target_rails_prerelease

      def create_root_files
        build(:readme)
        build(:rakefile)
        build(:node_version) if using_node?
        build(:ruby_version)
        build(:configru)

        unless options[:skip_git]
          build(:gitignore)
          build(:gitattributes)
        end

        build(:gemfile)
        build(:version_control)
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

      def update_active_storage
        unless skip_active_storage?
          rails_command "active_storage:update", inline: true
        end
      end
      remove_task :update_active_storage

      def create_dockerfiles
        return if options[:skip_docker] || options[:dummy_app]
        build(:dockerfiles)
      end

      def create_rubocop_file
        return if skip_rubocop?
        build(:rubocop)
      end

      def create_cifiles
        return if skip_ci?
        build(:cifiles)
      end

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
        build(:credentials_diff_enroll)
      end

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

      def create_script_folder
        return if options[:dummy_app]
        build(:script)
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
        build(:storage) unless skip_storage?
      end

      def create_devcontainer_files
        return if skip_devcontainer? || options[:dummy_app]
        build(:devcontainer)
      end

      def delete_app_assets_if_api_option
        if options[:api]
          remove_dir "app/assets"
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
            remove_dir  "app/views/pwa"
          end
        end
      end

      def delete_public_files_if_api_option
        if options[:api]
          remove_file "public/400.html"
          remove_file "public/404.html"
          remove_file "public/406-unsupported-browser.html"
          remove_file "public/422.html"
          remove_file "public/500.html"
          remove_file "public/icon.png"
          remove_file "public/icon.svg"
        end
      end

      def delete_assets_initializer_skipping_asset_pipeline
        if skip_asset_pipeline?
          remove_file "config/initializers/assets.rb"
          remove_file "app/assets/stylesheets/application.css"
          create_file "app/assets/stylesheets/application.css", "/* Application styles */\n" unless options[:api]
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
        end
      end

      def delete_non_api_initializers_if_api_option
        if options[:api]
          remove_file "config/initializers/content_security_policy.rb"
        end
      end

      def delete_api_initializers
        unless options[:api]
          remove_file "config/initializers/cors.rb"
        end
      end

      def delete_new_framework_defaults
        unless options[:update]
          remove_file "config/initializers/new_framework_defaults_#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}.rb"
        end
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template
      public_task :run_bundle
      public_task :add_bundler_platforms
      public_task :generate_bundler_binstub
      public_task :run_javascript
      public_task :run_hotwire
      public_task :run_css
      public_task :run_kamal
      public_task :run_solid

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

      # Registers a callback to be executed after bundle binstubs
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
          extra_args = File.readlines(railsrc).flat_map.each { |line| line.split("#", 2).first.split }
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
