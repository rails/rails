# frozen_string_literal: true

require "active_support/core_ext/hash/except"
require "rails/generators/rails/app/app_generator"
require "date"

module Rails
  # The plugin builder allows you to override elements of the plugin
  # generator without being forced to reverse the operations of the default
  # generator.
  #
  # This allows you to override entire operations, like the creation of the
  # Gemfile, \README, or JavaScript files, without needing to know exactly
  # what those operations do so you can create another template action.
  class PluginBuilder
    def rakefile
      template "Rakefile"
    end

    def app
      if mountable?
        if api?
          directory "app", exclude_pattern: %r{app/(views|helpers)}
        else
          directory "app"
          empty_directory_with_keep_file "app/assets/images/#{namespaced_name}"
        end

        empty_directory_with_keep_file "app/models/concerns"
        empty_directory_with_keep_file "app/controllers/concerns"
        remove_dir "app/mailers" if options[:skip_action_mailer]
        remove_dir "app/jobs" if options[:skip_active_job]
      elsif full?
        empty_directory_with_keep_file "app/models"
        empty_directory_with_keep_file "app/controllers"
        empty_directory_with_keep_file "app/models/concerns"
        empty_directory_with_keep_file "app/controllers/concerns"
        empty_directory_with_keep_file "app/mailers" unless options[:skip_action_mailer]
        empty_directory_with_keep_file "app/jobs" unless options[:skip_active_job]

        unless api?
          empty_directory_with_keep_file "app/assets/images/#{namespaced_name}"
          empty_directory_with_keep_file "app/helpers"
          empty_directory_with_keep_file "app/views"
        end
      end
    end

    def readme
      template "README.md"
    end

    def gemfile
      template "Gemfile"
    end

    def license
      template "MIT-LICENSE" unless inside_application?
    end

    def gemspec
      template "%name%.gemspec"
    end

    def gitignore
      template "gitignore", ".gitignore"
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

    def lib
      template "lib/%namespaced_name%.rb"
      template "lib/tasks/%namespaced_name%_tasks.rake"
      template "lib/%namespaced_name%/version.rb"

      if engine?
        template "lib/%namespaced_name%/engine.rb"
      else
        template "lib/%namespaced_name%/railtie.rb"
      end
    end

    def config
      template "config/routes.rb" if engine?
    end

    def test
      template "test/test_helper.rb"
      template "test/%namespaced_name%_test.rb"

      if engine?
        empty_directory_with_keep_file "test/fixtures/files"
        empty_directory_with_keep_file "test/controllers"
        empty_directory_with_keep_file "test/mailers"
        empty_directory_with_keep_file "test/models"
        empty_directory_with_keep_file "test/integration"

        unless api?
          empty_directory_with_keep_file "test/helpers"
        end

        template "test/integration/navigation_test.rb"
      end
    end

    DUMMY_IGNORE_OPTIONS = %i[dev edge master template]

    def generate_test_dummy(force = false)
      opts = options.transform_keys(&:to_sym).except(*DUMMY_IGNORE_OPTIONS)
      opts[:force] = force
      opts[:skip_thruster] = true
      opts[:skip_brakeman] = true
      opts[:skip_bundle] = true
      opts[:skip_ci] = true
      opts[:skip_kamal] = true
      opts[:skip_solid] = true
      opts[:skip_git] = true
      opts[:skip_hotwire] = true
      opts[:skip_rubocop] = true
      opts[:dummy_app] = true

      invoke Rails::Generators::AppGenerator,
        [ File.expand_path(dummy_path, destination_root) ], opts
    end

    def test_dummy_config
      template "rails/boot.rb", "#{dummy_path}/config/boot.rb", force: true

      if mountable?
        template "rails/routes.rb", "#{dummy_path}/config/routes.rb", force: true
      end
      if engine? && !api?
        insert_into_file "#{dummy_path}/config/application.rb", indent(<<~RUBY, 4), after: /^\s*config\.load_defaults.*\n/

          # For compatibility with applications that use this config
          config.action_controller.include_all_helpers = false
        RUBY
      end
    end

    def test_dummy_assets
      template "rails/stylesheets.css", "#{dummy_path}/app/assets/stylesheets/application.css", force: true
    end

    def test_dummy_clean
      inside dummy_path do
        remove_file ".ruby-version"
        remove_dir "db"
        remove_file "Gemfile"
        remove_dir "lib"
        remove_file "public/robots.txt"
        remove_file "README.md"
        remove_file "test"
        remove_file "vendor"
      end
    end

    def stylesheets
      if mountable?
        copy_file "rails/stylesheets.css",
                  "app/assets/stylesheets/#{namespaced_name}/application.css"
      elsif full?
        empty_directory_with_keep_file "app/assets/stylesheets/#{namespaced_name}"
      end
    end

    def bin
      exclude_pattern = Regexp.union([(engine? ? /test\.tt/ : /rails\.tt/), (/rubocop/ if skip_rubocop?)].compact)
      directory "bin", { exclude_pattern: exclude_pattern } do |content|
        "#{shebang}\n" + content
      end
      chmod "bin", 0755 & ~File.umask, verbose: false
    end

    def gemfile_entry
      return unless inside_application?

      gemfile_in_app_path = File.join(rails_app_path, "Gemfile")
      if File.exist? gemfile_in_app_path
        entry = %{\ngem "#{name}", path: "#{relative_path}"}
        append_file gemfile_in_app_path, entry
      end
    end
  end

  module Generators
    class PluginGenerator < AppBase # :nodoc:
      add_shared_options_for "plugin"

      alias_method :plugin_path, :app_path

      class_option :dummy_path,   type: :string, default: "test/dummy",
                                  desc: "Create dummy application at given path"

      class_option :full,         type: :boolean, default: false,
                                  desc: "Generate a rails engine with bundled Rails application for testing"

      class_option :mountable,    type: :boolean, default: false,
                                  desc: "Generate mountable isolated engine"

      class_option :skip_gemspec, type: :boolean, default: false,
                                  desc: "Skip gemspec file"

      class_option :skip_gemfile_entry, type: :boolean, default: false,
                                        desc: "If creating plugin in application's directory " \
                                                 "skip adding entry to Gemfile"

      class_option :api,          type: :boolean, default: false,
                                  desc: "Generate a smaller stack for API application plugins"

      def initialize(*args)
        @dummy_path = nil
        super
        imply_options

        if !engine? || !with_dummy_app?
          self.options = options.merge(skip_asset_pipeline: true).freeze
        end
      end

      public_task :report_implied_options
      public_task :set_default_accessors!
      public_task :create_root

      def target_rails_prerelease
        super("plugin new")
      end

      def create_root_files
        build(:readme)
        build(:rakefile)
        build(:gemspec)   unless options[:skip_gemspec]
        build(:license)
        build(:gitignore) unless options[:skip_git]
        build(:gemfile)
        build(:version_control)
      end

      def create_app_files
        build(:app)
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

      def create_lib_files
        build(:lib)
      end

      def create_assets_manifest_file
        build(:assets_manifest) if !api? && engine?
      end

      def create_public_stylesheets_files
        build(:stylesheets) unless api?
      end

      def create_bin_files
        build(:bin)
      end

      def create_test_files
        build(:test) unless options[:skip_test]
      end

      def create_test_dummy_files
        return unless with_dummy_app?
        create_dummy_app
      end

      def update_gemfile
        build(:gemfile_entry) unless options[:skip_gemfile_entry]
      end

      def finish_template
        build(:leftovers)
      end

      public_task :apply_rails_template

      def name
        @name ||= begin
          # same as ActiveSupport::Inflector#underscore except not replacing '-'
          underscored = original_name.dup
          underscored.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          underscored.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          underscored.downcase!

          underscored
        end
      end

      def underscored_name
        @underscored_name ||= original_name.underscore
      end

      def namespaced_name
        @namespaced_name ||= name.tr("-", "/")
      end

    private
      def gemfile_entries
        [
          rails_gemfile_entry,
          simplify_gemfile_entries(
            web_server_gemfile_entry,
            database_gemfile_entry,
            asset_pipeline_gemfile_entry,
          ),
        ].flatten.compact
      end

      def rails_gemfile_entry
        if options[:skip_gemspec]
          super
        elsif rails_prerelease?
          super.dup.tap do |entry|
            entry.comment = <<~COMMENT
              Your gem is dependent on a prerelease version of Rails. Once you can lock this
              dependency down to a specific version, move it to your gemspec.
            COMMENT
          end
        end
      end

      def simplify_gemfile_entries(*gemfile_entries)
        gemfile_entries.flatten.compact.map { |entry| GemfileEntry.floats(entry.name) }
      end

      def create_dummy_app(path = nil)
        dummy_path(path) if path

        say_status :vendor_app, dummy_path
        mute do
          build(:generate_test_dummy)
          build(:test_dummy_config)
          build(:test_dummy_assets) unless skip_asset_pipeline?
          build(:test_dummy_clean)
          # ensure that bin/rails has proper dummy_path
          build(:bin)
        end
      end

      def engine?
        full? || mountable? || options[:engine]
      end

      def full?
        options[:full]
      end

      def mountable?
        options[:mountable]
      end

      def skip_git?
        options[:skip_git]
      end

      def with_dummy_app?
        options[:skip_test].blank? || options[:dummy_path] != "test/dummy"
      end

      def api?
        options[:api]
      end

      def self.banner
        "rails plugin new #{arguments.map(&:usage).join(' ')} [options]"
      end

      def original_name
        @original_name ||= File.basename(destination_root)
      end

      def modules
        @modules ||= namespaced_name.camelize.split("::")
      end

      def wrap_in_modules(unwrapped_code)
        unwrapped_code = "#{unwrapped_code}".strip.gsub(/\s$\n/, "")
        modules.reverse.inject(unwrapped_code) do |content, mod|
          str = +"module #{mod}\n"
          str << content.lines.map { |line| "  #{line}" }.join
          str << (content.present? ? "\nend" : "end")
        end
      end

      def camelized_modules
        @camelized_modules ||= namespaced_name.camelize
      end

      def humanized
        @humanized ||= original_name.underscore.humanize
      end

      def camelized
        @camelized ||= name.gsub(/\W/, "_").squeeze("_").camelize
      end

      def author
        default = "TODO: Write your name"
        if skip_git?
          @author = default
        else
          @author = `git config user.name`.chomp rescue default
        end
      end

      def email
        default = "TODO: Write your email address"
        if skip_git?
          @email = default
        else
          @email = `git config user.email`.chomp rescue default
        end
      end

      def rails_version_specifier(gem_version = Rails.gem_version)
        [">= #{gem_version}"]
      end

      def valid_const?
        if /-\d/.match?(original_name)
          raise Error, "Invalid plugin name #{original_name}. Please give a name which does not contain a namespace starting with numeric characters."
        elsif /[^\w-]+/.match?(original_name)
          raise Error, "Invalid plugin name #{original_name}. Please give a name which uses only alphabetic, numeric, \"_\" or \"-\" characters."
        elsif /^\d/.match?(camelized)
          raise Error, "Invalid plugin name #{original_name}. Please give a name which does not start with numbers."
        elsif RESERVED_NAMES.include?(name)
          raise Error, "Invalid plugin name #{original_name}. Please give a " \
                       "name which does not match one of the reserved rails " \
                       "words: #{RESERVED_NAMES.join(", ")}"
        elsif Object.const_defined?(camelized)
          raise Error, "Invalid plugin name #{original_name}, constant #{camelized} is already in use. Please choose another plugin name."
        end
      end

      def get_builder_class
        defined?(::PluginBuilder) ? ::PluginBuilder : Rails::PluginBuilder
      end

      def dummy_path(path = nil)
        @dummy_path = path if path
        @dummy_path || options[:dummy_path]
      end

      def mute(&block)
        shell.mute(&block)
      end

      def rails_app_path
        APP_PATH.sub("/config/application", "") if defined?(APP_PATH)
      end

      def inside_application?
        rails_app_path && destination_root.start_with?(rails_app_path.to_s)
      end

      def relative_path
        return unless inside_application?
        app_path.delete_prefix("#{rails_app_path}/")
      end

      def test_command
        if engine? && !options[:skip_active_record] && with_dummy_app?
          "bin/rails db:test:prepare test"
        elsif engine?
          "bin/rails test"
        else
          "bin/test"
        end
      end
    end
  end
end
