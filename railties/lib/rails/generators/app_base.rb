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
        class_option :name,                type: :string, aliases: "-n",
                                           desc: "Name of the app"

        class_option :template,            type: :string, aliases: "-m",
                                           desc: "Path to some #{name} template (can be a filesystem path or URL)"

        class_option :database,            type: :string, aliases: "-d", default: "sqlite3",
                                           desc: "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :skip_git,            type: :boolean, aliases: "-G", default: false,
                                           desc: "Skip git init, .gitignore and .gitattributes"

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

        class_option :skip_active_job,     type: :boolean, default: false,
                                           desc: "Skip Active Job"

        class_option :skip_active_storage, type: :boolean, default: false,
                                           desc: "Skip Active Storage files"

        class_option :skip_action_cable,   type: :boolean, aliases: "-C", default: false,
                                           desc: "Skip Action Cable files"

        class_option :skip_asset_pipeline, type: :boolean, aliases: "-A", default: false

        class_option :asset_pipeline,      type: :string, aliases: "-a", default: "sprockets",
                                           desc: "Choose your asset pipeline [options: sprockets (default), propshaft]"

        class_option :skip_javascript,     type: :boolean, aliases: ["-J", "--skip-js"], default: name == "plugin",
                                           desc: "Skip JavaScript files"

        class_option :skip_hotwire,        type: :boolean, default: false,
                                           desc: "Skip Hotwire integration"

        class_option :skip_jbuilder,       type: :boolean, default: false,
                                           desc: "Skip jbuilder gem"

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

        class_option :main,                type: :boolean, default: false, aliases: "--master",
                                           desc: "Set up the #{name} with Gemfile pointing to Rails repository main branch"

        class_option :rc,                  type: :string, default: nil,
                                           desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,               type: :boolean, default: false,
                                           desc: "Skip loading of extra configuration options from .railsrc file"

        class_option :help,                type: :boolean, aliases: "-h", group: :rails,
                                           desc: "Show this help message and quit"
      end

      def initialize(positional_argv, option_argv, *)
        @argv = [*positional_argv, *option_argv]
        @gem_filter = lambda { |gem| true }
        super
      end

    private
      def gemfile_entries # :doc:
        [
          rails_gemfile_entry,
          asset_pipeline_gemfile_entry,
          database_gemfile_entry,
          web_server_gemfile_entry,
          javascript_gemfile_entry,
          hotwire_gemfile_entry,
          css_gemfile_entry,
          jbuilder_gemfile_entry,
          psych_gemfile_entry,
          cable_gemfile_entry,
        ].flatten.compact.select(&@gem_filter)
      end

      def builder # :doc:
        @builder ||= begin
          builder_class = get_builder_class
          builder_class.include(ActionMethods)
          builder_class.new(self)
        end
      end

      def build(meth, *args) # :doc:
        builder.public_send(meth, *args) if builder.respond_to?(meth)
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
            File.expand_path(`echo #{options[:template]}`.strip)
          else
            options[:template]
          end
      end

      def database_gemfile_entry # :doc:
        return if options[:skip_active_record]

        gem_name, gem_version = gem_for_database
        GemfileEntry.version gem_name, gem_version,
          "Use #{options[:database]} as the database for Active Record"
      end

      def web_server_gemfile_entry # :doc:
        GemfileEntry.new "puma", "~> 5.0", "Use the Puma web server [https://github.com/puma/puma]"
      end

      def asset_pipeline_gemfile_entry
        return if options[:skip_asset_pipeline]

        if options[:asset_pipeline] == "sprockets"
          GemfileEntry.floats "sprockets-rails",
            "The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]"
        elsif options[:asset_pipeline] == "propshaft"
          GemfileEntry.floats "propshaft", "The modern asset pipeline for Rails [https://github.com/rails/propshaft]"
        end
      end

      def include_all_railties? # :doc:
        [
          options.values_at(
            :skip_active_record,
            :skip_action_mailer,
            :skip_test,
            :skip_action_cable,
            :skip_active_job
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

      def skip_dev_gems? # :doc:
        options[:skip_dev_gems]
      end

      def skip_sprockets?
        options[:skip_asset_pipeline] || options[:asset_pipeline] != "sprockets"
      end

      def skip_propshaft?
        options[:skip_asset_pipeline] || options[:asset_pipeline] != "propshaft"
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

        def self.floats(name, comment = nil)
          new(name, nil, comment)
        end

        def self.path(name, path, comment = nil)
          new(name, nil, comment, path: path)
        end

        def to_s
          [
            (comment.gsub(/^/, "# ").chomp + "\n" if comment),
            ("# " if commented_out),
            "gem \"#{name}\"",
            *Array(version).map { |constraint| ", \"#{constraint}\"" },
            *options.map { |key, value| ", #{key}: #{value.inspect}" },
          ].compact.join
        end
      end

      def rails_prerelease?
        options.dev? || options.edge? || options.main?
      end

      def rails_gemfile_entry
        if options.dev?
          GemfileEntry.path("rails", Rails::Generators::RAILS_DEV_PATH, "Use local checkout of Rails")
        elsif options.edge?
          edge_branch = Rails.gem_version.prerelease? ? "main" : [*Rails.gem_version.segments.first(2), "stable"].join("-")
          GemfileEntry.github("rails", "rails/rails", edge_branch, "Use specific branch of Rails")
        elsif options.main?
          GemfileEntry.github("rails", "rails/rails", "main", "Use main development branch of Rails")
        else
          GemfileEntry.version("rails", rails_version_specifier,
            %(Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"))
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

      def jbuilder_gemfile_entry
        return if options[:skip_jbuilder]
        GemfileEntry.new "jbuilder", nil, "Build JSON APIs with ease [https://github.com/rails/jbuilder]", {}, options[:api]
      end

      def javascript_gemfile_entry
        return if options[:skip_javascript]

        if adjusted_javascript_option == "importmap"
          GemfileEntry.floats "importmap-rails", "Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]"
        else
          GemfileEntry.floats "jsbundling-rails", "Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]"
        end
      end

      def hotwire_gemfile_entry
        return if options[:skip_javascript] || options[:skip_hotwire]

        turbo_rails_entry =
          GemfileEntry.floats "turbo-rails", "Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]"

        stimulus_rails_entry =
          GemfileEntry.floats "stimulus-rails", "Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]"

        [ turbo_rails_entry, stimulus_rails_entry ]
      end

      def using_node?
        options[:javascript] && options[:javascript] != "importmap"
      end

      # CSS processors other than Tailwind require a node-based JavaScript environment. So overwrite the normal JS default
      # if one such processor has been specified.
      def adjusted_javascript_option
        if options[:css] && options[:css] != "tailwind" && options[:javascript] == "importmap"
          "esbuild"
        else
          options[:javascript]
        end
      end

      def css_gemfile_entry
        return unless options[:css]

        if !using_node? && options[:css] == "tailwind"
          GemfileEntry.floats "tailwindcss-rails", "Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]"
        else
          GemfileEntry.floats "cssbundling-rails", "Bundle and process CSS [https://github.com/rails/cssbundling-rails]"
        end
      end

      def psych_gemfile_entry
        return unless defined?(Rubinius)

        comment = "Use Psych as the YAML engine, instead of Syck, so serialized " \
                  "data can be read safely from different rubies"
        GemfileEntry.new("psych", "~> 2.0", comment, platforms: :rbx)
      end

      def cable_gemfile_entry
        return if options[:skip_action_cable]

        comment = "Use Redis adapter to run Action Cable in production"
        GemfileEntry.new("redis", "~> 4.0", comment, {}, true)
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
        !(options[:skip_bundle] || options[:pretend])
      end

      def depends_on_system_test?
        !(options[:skip_system_test] || options[:skip_test] || options[:api])
      end

      def depend_on_bootsnap?
        !options[:skip_bootsnap] && !options[:dev] && !defined?(JRUBY_VERSION)
      end

      def target_rails_prerelease(self_command = "new")
        return unless rails_prerelease? && bundle_install?

        if !File.exist?(File.expand_path("Gemfile", destination_root))
          create_file("Gemfile", <<~GEMFILE)
            source "https://rubygems.org"
            git_source(:github) { |repo| "https://github.com/\#{repo}.git" }
            #{rails_gemfile_entry}
          GEMFILE

          run_bundle

          @argv[0] = destination_root
          require "shellwords"
          bundle_command("exec rails #{self_command} #{Shellwords.join(@argv)}")
          exit
        else
          remove_file("Gemfile")
          remove_file("Gemfile.lock")
        end
      end

      def run_bundle
        bundle_command("install", "BUNDLE_IGNORE_MESSAGES" => "1") if bundle_install?
      end

      def run_javascript
        return if options[:skip_javascript] || !bundle_install?

        case adjusted_javascript_option
        when "importmap"                    then rails_command "importmap:install"
        when "webpack", "esbuild", "rollup" then rails_command "javascript:install:#{adjusted_javascript_option}"
        end
      end

      def run_hotwire
        return if options[:skip_javascript] || options[:skip_hotwire] || !bundle_install?

        rails_command "turbo:install stimulus:install"
      end

      def run_css
        return if !options[:css] || !bundle_install?

        if !using_node? && options[:css] == "tailwind"
          rails_command "tailwindcss:install"
        else
          rails_command "css:install:#{options[:css]}"
        end
      end

      def generate_bundler_binstub
        if bundle_install?
          bundle_command("binstubs bundler")
        end
      end

      def empty_directory_with_keep_file(destination, config = {})
        empty_directory(destination, config)
        keep_file(destination)
      end

      def keep_file(destination)
        create_file("#{destination}/.keep") if keeps?
      end

      def user_default_branch
        @user_default_branch ||= `git config init.defaultbranch`
      end

      def git_init_command
        return "git init" if user_default_branch.strip.present?

        git_version = `git --version`[/\d+\.\d+\.\d+/]

        if Gem::Version.new(git_version) >= Gem::Version.new("2.28.0")
          "git init -b main"
        else
          "git init && git symbolic-ref HEAD refs/heads/main"
        end
      end
    end
  end
end
