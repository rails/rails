# frozen_string_literal: true

require "fileutils"
require "digest/md5"
require "rails/version" unless defined?(Rails::VERSION)
require "open-uri"
require "uri"
require "rails/generators"
require "active_support/core_ext/array/extract_options"

module Rails
  module Generators
    class AppBase < Base # :nodoc:
      include Database
      include AppName

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

        class_option :skip_gemfile,        type: :boolean, default: false,
                                           desc: "Don't create a Gemfile"

        class_option :skip_git,            type: :boolean, aliases: "-G", default: false,
                                           desc: "Skip .gitignore file"

        class_option :skip_keeps,          type: :boolean, default: false,
                                           desc: "Skip source control .keep files"

        class_option :skip_action_mailer,  type: :boolean, aliases: "-M",
                                           default: false,
                                           desc: "Skip Action Mailer files"

        class_option :skip_action_mailbox, type: :boolean, default: false,
                                           desc: "Skip Action Mailbox gem"

        class_option :skip_action_text,    type: :boolean, default: false,
                                           desc: "Skip Action Text gem"

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

        class_option :skip_javascript,     type: :boolean, aliases: "-J", default: name == "plugin",
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
                                           desc: "Set up the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,                type: :boolean, default: false,
                                           desc: "Set up the #{name} with Gemfile pointing to Rails repository"

        class_option :master,              type: :boolean, default: false,
                                           desc: "Set up the #{name} with Gemfile pointing to Rails repository master branch"

        class_option :rc,                  type: :string, default: nil,
                                           desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,               type: :boolean, default: false,
                                           desc: "Skip loading of extra configuration options from .railsrc file"

        class_option :help,                type: :boolean, aliases: "-h", group: :rails,
                                           desc: "Show this help message and quit"
      end

      def initialize(*args)
        @gem_filter    = lambda { |gem| true }
        super
      end

    private
      def gemfile_entries # :doc:
        [rails_gemfile_entry,
         database_gemfile_entry,
         web_server_gemfile_entry,
         assets_gemfile_entry,
         webpacker_gemfile_entry,
         javascript_gemfile_entry,
         jbuilder_gemfile_entry,
         psych_gemfile_entry,
         cable_gemfile_entry].flatten.find_all(&@gem_filter)
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

      def web_server_gemfile_entry # :doc:
        return [] if options[:skip_puma]
        comment = "Use Puma as the app server"
        GemfileEntry.new("puma", "~> 4.1", comment)
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
          skip_active_storage?,
          skip_action_mailbox?,
          skip_action_text?
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

      def skip_action_mailbox? # :doc:
        options[:skip_action_mailbox] || skip_active_storage?
      end

      def skip_action_text? # :doc:
        options[:skip_action_text] || skip_active_storage?
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
            GemfileEntry.github("rails", "rails/rails")
          ]
        elsif options.master?
          [
            GemfileEntry.github("rails", "rails/rails", "master")
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

      def assets_gemfile_entry
        return [] if options[:skip_sprockets]

        GemfileEntry.version("sass-rails", ">= 6", "Use SCSS for stylesheets")
      end

      def webpacker_gemfile_entry
        return [] if options[:skip_javascript]

        if options.dev? || options.edge? || options.master?
          GemfileEntry.github "webpacker", "rails/webpacker", nil, "Use development version of Webpacker"
        else
          GemfileEntry.version "webpacker", "~> 5.0", "Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker"
        end
      end

      def jbuilder_gemfile_entry
        comment = "Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder"
        GemfileEntry.new "jbuilder", "~> 2.7", comment, {}, options[:api]
      end

      def javascript_gemfile_entry
        if options[:skip_javascript] || options[:skip_turbolinks]
          []
        else
          [ GemfileEntry.version("turbolinks", "~> 5",
             "Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks") ]
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

      def bundle_command(command, env = {})
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
          exec_bundle_command(_bundle_command, command, env)
        end
      end

      def exec_bundle_command(bundle_command, command, env)
        full_command = %Q["#{Gem.ruby}" "#{bundle_command}" #{command}]
        if options[:quiet]
          system(env, full_command, out: File::NULL)
        else
          system(env, full_command)
        end
      end

      def bundle_install?
        !(options[:skip_gemfile] || options[:skip_bundle] || options[:pretend])
      end

      def spring_install?
        !options[:skip_spring] && !options.dev? && Process.respond_to?(:fork) && !RUBY_PLATFORM.include?("cygwin")
      end

      def webpack_install?
        !(options[:skip_javascript] || options[:skip_webpack_install])
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
        /darwin|linux/.match?(RbConfig::CONFIG["host_os"])
      end

      def run_bundle
        bundle_command("install", "BUNDLE_IGNORE_MESSAGES" => "1") if bundle_install?
      end

      def run_webpack
        if webpack_install?
          rails_command "webpacker:install", inline: true
          if options[:webpack] && options[:webpack] != "webpack"
            rails_command "webpacker:install:#{options[:webpack]}", inline: true
          end
        end
      end

      def generate_bundler_binstub
        if bundle_install?
          bundle_command("binstubs bundler")
        end
      end

      def generate_spring_binstub
        if bundle_install? && spring_install?
          bundle_command("exec spring binstub")
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
