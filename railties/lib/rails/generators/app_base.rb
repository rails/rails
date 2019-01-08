# frozen_string_literal: true

require "fileutils"
require "digest/md5"
require "active_support/core_ext/string/strip"
require "rails/version" unless defined?(Rails::VERSION)
require "open-uri"
require "uri"
require "rails/generators"
require "active_support/core_ext/array/extract_options"

module Rails
  module Generators
    class AppBase < Base # :nodoc:
      DATABASES = %w( mysql postgresql sqlite3 oracle frontbase ibm_db sqlserver )
      JDBC_DATABASES = %w( jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc )
      DATABASES.concat(JDBC_DATABASES)

      attr_accessor :rails_template
      add_shebang_option!

      argument :app_path, type: :string

      def self.strict_args_position
        false
      end

      def self.add_shared_options_for(name)
        class_option :template,            type: :string, aliases: "-m",
                                           desc: "Path to some #{name} template (can be a filesystem path or URL)"

        class_option :database,            type: :string, aliases: "-d", default: "sqlite3",
                                           desc: "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :skip_yarn,           type: :boolean, default: false,
                                           desc: "Don't use Yarn for managing JavaScript dependencies"

        class_option :skip_gemfile,        type: :boolean, default: false,
                                           desc: "Don't create a Gemfile"

        class_option :skip_git,            type: :boolean, aliases: "-G", default: false,
                                           desc: "Skip .gitignore file"

        class_option :skip_keeps,          type: :boolean, default: false,
                                           desc: "Skip source control .keep files"

        class_option :skip_action_mailer,  type: :boolean, aliases: "-M",
                                           default: false,
                                           desc: "Skip Action Mailer files"

        class_option :skip_active_record,  type: :boolean, aliases: "-O", default: false,
                                           desc: "Skip Active Record files"

        class_option :skip_active_storage, type: :boolean, default: false,
                                           desc: "Skip Active Storage files"

        class_option :skip_puma,           type: :boolean, aliases: "-P", default: false,
                                           desc: "Skip Puma related files"

        class_option :skip_action_cable,   type: :boolean, aliases: "-C", default: false,
                                           desc: "Skip Action Cable files"

        class_option :skip_sprockets,      type: :boolean, aliases: "-S", default: false,
                                           desc: "Skip Sprockets files"

        class_option :skip_spring,         type: :boolean, default: false,
                                           desc: "Don't install Spring application preloader"

        class_option :skip_listen,         type: :boolean, default: false,
                                           desc: "Don't generate configuration that depends on the listen gem"

        class_option :skip_coffee,         type: :boolean, default: false,
                                           desc: "Don't use CoffeeScript"

        class_option :skip_javascript,     type: :boolean, aliases: "-J", default: false,
                                           desc: "Skip JavaScript files"

        class_option :skip_turbolinks,     type: :boolean, default: false,
                                           desc: "Skip turbolinks gem"

        class_option :skip_test,           type: :boolean, aliases: "-T", default: false,
                                           desc: "Skip test files"

        class_option :skip_system_test,    type: :boolean, default: false,
                                           desc: "Skip system test files"

        class_option :skip_bootsnap,       type: :boolean, default: false,
                                           desc: "Skip bootsnap gem"

        class_option :dev,                 type: :boolean, default: false,
                                           desc: "Setup the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,                type: :boolean, default: false,
                                           desc: "Setup the #{name} with Gemfile pointing to Rails repository"

        class_option :rc,                  type: :string, default: nil,
                                           desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,               type: :boolean, default: false,
                                           desc: "Skip loading of extra configuration options from .railsrc file"

        class_option :help,                type: :boolean, aliases: "-h", group: :rails,
                                           desc: "Show this help message and quit"
      end

      def initialize(*args)
        @gem_filter    = lambda { |gem| true }
        @extra_entries = []
        super
        convert_database_option_for_jruby
      end

    private

      def gemfile_entry(name, *args) # :doc:
        options = args.extract_options!
        version = args.first
        github = options[:github]
        path   = options[:path]

        if github
          @extra_entries << GemfileEntry.github(name, github)
        elsif path
          @extra_entries << GemfileEntry.path(name, path)
        else
          @extra_entries << GemfileEntry.version(name, version)
        end
        self
      end

      def gemfile_entries # :doc:
        [rails_gemfile_entry,
         database_gemfile_entry,
         webserver_gemfile_entry,
         assets_gemfile_entry,
         webpacker_gemfile_entry,
         javascript_gemfile_entry,
         jbuilder_gemfile_entry,
         psych_gemfile_entry,
         cable_gemfile_entry,
         @extra_entries].flatten.find_all(&@gem_filter)
      end

      def add_gem_entry_filter # :doc:
        @gem_filter = lambda { |next_filter, entry|
          yield(entry) && next_filter.call(entry)
        }.curry[@gem_filter]
      end

      def builder # :doc:
        @builder ||= begin
          builder_class = get_builder_class
          builder_class.include(ActionMethods)
          builder_class.new(self)
        end
      end

      def build(meth, *args) # :doc:
        builder.send(meth, *args) if builder.respond_to?(meth)
      end

      def create_root # :doc:
        valid_const?

        empty_directory "."
        FileUtils.cd(destination_root) unless options[:pretend]
      end

      def apply_rails_template # :doc:
        apply rails_template if rails_template
      rescue Thor::Error, LoadError, Errno::ENOENT => e
        raise Error, "The template [#{rails_template}] could not be loaded. Error: #{e}"
      end

      def set_default_accessors! # :doc:
        self.destination_root = File.expand_path(app_path, destination_root)
        self.rails_template = \
          case options[:template]
          when /^https?:\/\//
            options[:template]
          when String
            File.expand_path(options[:template], Dir.pwd)
          else
            options[:template]
          end
      end

      def database_gemfile_entry # :doc:
        return [] if options[:skip_active_record]
        gem_name, gem_version = gem_for_database
        GemfileEntry.version gem_name, gem_version,
                            "Use #{options[:database]} as the database for Active Record"
      end

      def webserver_gemfile_entry # :doc:
        return [] if options[:skip_puma]
        comment = "Use Puma as the app server"
        GemfileEntry.new("puma", "~> 3.11", comment)
      end

      def include_all_railties? # :doc:
        [
          options.values_at(
            :skip_active_record,
            :skip_action_mailer,
            :skip_test,
            :skip_sprockets,
            :skip_action_cable
          ),
          skip_active_storage?
        ].flatten.none?
      end

      def comment_if(value) # :doc:
        question = "#{value}?"

        comment =
          if respond_to?(question, true)
            send(question)
          else
            options[value]
          end

        comment ? "# " : ""
      end

      def keeps? # :doc:
        !options[:skip_keeps]
      end

      def sqlite3? # :doc:
        !options[:skip_active_record] && options[:database] == "sqlite3"
      end

      def skip_active_storage? # :doc:
        options[:skip_active_storage] || options[:skip_active_record]
      end

      class GemfileEntry < Struct.new(:name, :version, :comment, :options, :commented_out)
        def initialize(name, version, comment, options = {}, commented_out = false)
          super
        end

        def self.github(name, github, branch = nil, comment = nil)
          if branch
            new(name, nil, comment, github: github, branch: branch)
          else
            new(name, nil, comment, github: github)
          end
        end

        def self.version(name, version, comment = nil)
          new(name, version, comment)
        end

        def self.path(name, path, comment = nil)
          new(name, nil, comment, path: path)
        end

        def version
          version = super

          if version.is_a?(Array)
            version.join("', '")
          else
            version
          end
        end
      end

      def rails_gemfile_entry
        if options.dev?
          [
            GemfileEntry.path("rails", Rails::Generators::RAILS_DEV_PATH)
          ]
        elsif options.edge?
          [
            GemfileEntry.github("rails", "rails/rails", "5-2-stable")
          ]
        else
          [GemfileEntry.version("rails",
                            rails_version_specifier,
                            "Bundle edge Rails instead: gem 'rails', github: 'rails/rails'")]
        end
      end

      def rails_version_specifier(gem_version = Rails.gem_version)
        if gem_version.segments.size == 3 || gem_version.release.segments.size == 3
          # ~> 1.2.3
          # ~> 1.2.3.pre4
          "~> #{gem_version}"
        else
          # ~> 1.2.3, >= 1.2.3.4
          # ~> 1.2.3, >= 1.2.3.4.pre5
          patch = gem_version.segments[0, 3].join(".")
          ["~> #{patch}", ">= #{gem_version}"]
        end
      end

      def gem_for_database
        # %w( mysql postgresql sqlite3 oracle frontbase ibm_db sqlserver jdbcmysql jdbcsqlite3 jdbcpostgresql )
        case options[:database]
        when "mysql"          then ["mysql2", [">= 0.4.4", "< 0.6.0"]]
        when "postgresql"     then ["pg", [">= 0.18", "< 2.0"]]
        when "oracle"         then ["activerecord-oracle_enhanced-adapter", nil]
        when "frontbase"      then ["ruby-frontbase", nil]
        when "sqlserver"      then ["activerecord-sqlserver-adapter", nil]
        when "jdbcmysql"      then ["activerecord-jdbcmysql-adapter", nil]
        when "jdbcsqlite3"    then ["activerecord-jdbcsqlite3-adapter", nil]
        when "jdbcpostgresql" then ["activerecord-jdbcpostgresql-adapter", nil]
        when "jdbc"           then ["activerecord-jdbc-adapter", nil]
        else [options[:database], nil]
        end
      end

      def convert_database_option_for_jruby
        if defined?(JRUBY_VERSION)
          opt = options.dup
          case opt[:database]
          when "postgresql" then opt[:database] = "jdbcpostgresql"
          when "mysql"      then opt[:database] = "jdbcmysql"
          when "sqlite3"    then opt[:database] = "jdbcsqlite3"
          end
          self.options = opt.freeze
        end
      end

      def assets_gemfile_entry
        return [] if options[:skip_sprockets]

        gems = []
        gems << GemfileEntry.version("sass-rails", "~> 5.0",
                                     "Use SCSS for stylesheets")

        if !options[:skip_javascript]
          gems << GemfileEntry.version("uglifier",
                                     ">= 1.3.0",
                                     "Use Uglifier as compressor for JavaScript assets")
        end

        gems
      end

      def webpacker_gemfile_entry
        return [] unless options[:webpack]

        comment = "Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker"
        GemfileEntry.new "webpacker", nil, comment
      end

      def jbuilder_gemfile_entry
        comment = "Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder"
        GemfileEntry.new "jbuilder", "~> 2.5", comment, {}, options[:api]
      end

      def coffee_gemfile_entry
        GemfileEntry.version "coffee-rails", "~> 4.2", "Use CoffeeScript for .coffee assets and views"
      end

      def javascript_gemfile_entry
        if options[:skip_javascript] || options[:skip_sprockets]
          []
        else
          gems = [javascript_runtime_gemfile_entry]
          gems << coffee_gemfile_entry unless options[:skip_coffee]

          unless options[:skip_turbolinks]
            gems << GemfileEntry.version("turbolinks", "~> 5",
             "Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks")
          end

          gems
        end
      end

      def javascript_runtime_gemfile_entry
        comment = "See https://github.com/rails/execjs#readme for more supported runtimes"
        if defined?(JRUBY_VERSION)
          GemfileEntry.version "therubyrhino", nil, comment
        elsif RUBY_PLATFORM =~ /mingw|mswin/
          GemfileEntry.version "duktape", nil, comment
        else
          GemfileEntry.new "mini_racer", nil, comment, { platforms: :ruby }, true
        end
      end

      def psych_gemfile_entry
        return [] unless defined?(Rubinius)

        comment = "Use Psych as the YAML engine, instead of Syck, so serialized " \
                  "data can be read safely from different rubies (see http://git.io/uuLVag)"
        GemfileEntry.new("psych", "~> 2.0", comment, platforms: :rbx)
      end

      def cable_gemfile_entry
        return [] if options[:skip_action_cable]
        comment = "Use Redis adapter to run Action Cable in production"
        gems = []
        gems << GemfileEntry.new("redis", "~> 4.0", comment, {}, true)
        gems
      end

      def bundle_command(command)
        say_status :run, "bundle #{command}"

        # We are going to shell out rather than invoking Bundler::CLI.new(command)
        # because `rails new` loads the Thor gem and on the other hand bundler uses
        # its own vendored Thor, which could be a different version. Running both
        # things in the same process is a recipe for a night with paracetamol.
        #
        # Thanks to James Tucker for the Gem tricks involved in this call.
        _bundle_command = Gem.bin_path("bundler", "bundle")

        require "bundler"
        Bundler.with_original_env do
          exec_bundle_command(_bundle_command, command)
        end
      end

      def exec_bundle_command(bundle_command, command)
        full_command = %Q["#{Gem.ruby}" "#{bundle_command}" #{command}]
        if options[:quiet]
          system(full_command, out: File::NULL)
        else
          system(full_command)
        end
      end

      def bundle_install?
        !(options[:skip_gemfile] || options[:skip_bundle] || options[:pretend])
      end

      def spring_install?
        !options[:skip_spring] && !options.dev? && Process.respond_to?(:fork) && !RUBY_PLATFORM.include?("cygwin")
      end

      def depends_on_system_test?
        !(options[:skip_system_test] || options[:skip_test] || options[:api])
      end

      def depend_on_listen?
        !options[:skip_listen] && os_supports_listen_out_of_the_box?
      end

      def depend_on_bootsnap?
        !options[:skip_bootsnap] && !options[:dev] && !defined?(JRUBY_VERSION)
      end

      def os_supports_listen_out_of_the_box?
        RbConfig::CONFIG["host_os"] =~ /darwin|linux/
      end

      def run_bundle
        bundle_command("install") if bundle_install?
      end

      def run_webpack
        if !(webpack = options[:webpack]).nil?
          rails_command "webpacker:install"
          rails_command "webpacker:install:#{webpack}" unless webpack == "webpack"
        end
      end

      def generate_spring_binstubs
        if bundle_install? && spring_install?
          bundle_command("exec spring binstub --all")
        end
      end

      def empty_directory_with_keep_file(destination, config = {})
        empty_directory(destination, config)
        keep_file(destination)
      end

      def keep_file(destination)
        create_file("#{destination}/.keep") if keeps?
      end
    end
  end
end
