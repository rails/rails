# frozen_string_literal: true

require "fileutils"
require "digest/md5"
require "rails/version" unless defined?(Rails::VERSION)
require "open-uri"
require "tsort"
require "uri"
require "rails/generators"
require "active_support/core_ext/array/extract_options"

module Rails
  module Generators
    class AppBase < Base # :nodoc:
      include Database
      include AppName

      NODE_LTS_VERSION = "18.15.0"
      BUN_VERSION = "1.0.1"

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

        class_option :skip_git,            type: :boolean, aliases: "-G", default: nil,
                                           desc: "Skip git init, .gitignore and .gitattributes"

        class_option :skip_docker,         type: :boolean, default: nil,
                                           desc: "Skip Dockerfile, .dockerignore and bin/docker-entrypoint"

        class_option :skip_keeps,          type: :boolean, default: nil,
                                           desc: "Skip source control .keep files"

        class_option :skip_action_mailer,  type: :boolean, aliases: "-M",
                                           default: nil,
                                           desc: "Skip Action Mailer files"

        class_option :skip_action_mailbox, type: :boolean, default: nil,
                                           desc: "Skip Action Mailbox gem"

        class_option :skip_action_text,    type: :boolean, default: nil,
                                           desc: "Skip Action Text gem"

        class_option :skip_active_record,  type: :boolean, aliases: "-O", default: nil,
                                           desc: "Skip Active Record files"

        class_option :skip_active_job,     type: :boolean, default: nil,
                                           desc: "Skip Active Job"

        class_option :skip_active_storage, type: :boolean, default: nil,
                                           desc: "Skip Active Storage files"

        class_option :skip_action_cable,   type: :boolean, aliases: "-C", default: nil,
                                           desc: "Skip Action Cable files"

        class_option :skip_asset_pipeline, type: :boolean, aliases: "-A", default: nil

        class_option :asset_pipeline,      type: :string, aliases: "-a", default: "sprockets",
                                           desc: "Choose your asset pipeline [options: sprockets (default), propshaft]"

        class_option :skip_javascript,     type: :boolean, aliases: ["-J", "--skip-js"], default: (true if name == "plugin"),
                                           desc: "Skip JavaScript files"

        class_option :skip_hotwire,        type: :boolean, default: nil,
                                           desc: "Skip Hotwire integration"

        class_option :skip_jbuilder,       type: :boolean, default: nil,
                                           desc: "Skip jbuilder gem"

        class_option :skip_test,           type: :boolean, aliases: "-T", default: nil,
                                           desc: "Skip test files"

        class_option :skip_system_test,    type: :boolean, default: nil,
                                           desc: "Skip system test files"

        class_option :skip_bootsnap,       type: :boolean, default: nil,
                                           desc: "Skip bootsnap gem"

        class_option :skip_dev_gems,       type: :boolean, default: nil,
                                           desc: "Skip development gems (e.g., web-console)"

        class_option :dev,                 type: :boolean, default: nil,
                                           desc: "Set up the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,                type: :boolean, default: nil,
                                           desc: "Set up the #{name} with a Gemfile pointing to the #{edge_branch} branch on the Rails repository"

        class_option :main,                type: :boolean, default: nil, aliases: "--master",
                                           desc: "Set up the #{name} with Gemfile pointing to Rails repository main branch"

        class_option :rc,                  type: :string, default: nil,
                                           desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,               type: :boolean, default: nil,
                                           desc: "Skip loading of extra configuration options from .railsrc file"

        class_option :help,                type: :boolean, aliases: "-h", group: :rails,
                                           desc: "Show this help message and quit"
      end

      def self.edge_branch # :nodoc:
        Rails.gem_version.prerelease? ? "main" : [*Rails.gem_version.segments.first(2), "stable"].join("-")
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

      def deduce_implied_options(options, option_reasons, meta_options)
        active = options.transform_values { |value| [] if value }.compact
        irrevocable = (active.keys - meta_options).to_set

        deduction_order = TSort.tsort(
          ->(&block) { option_reasons.each_key(&block) },
          ->(key, &block) { option_reasons[key]&.each(&block) }
        )

        deduction_order.each do |name|
          active_reasons = option_reasons[name].to_a.select(&active)
          active[name] ||= active_reasons if active_reasons.any?
          irrevocable << name if active_reasons.any?(irrevocable)
        end

        revoked = options.select { |name, value| value == false }.keys.to_set - irrevocable
        deduction_order.reverse_each do |name|
          revoked += option_reasons[name].to_a if revoked.include?(name)
        end
        revoked -= meta_options

        active.filter_map do |name, reasons|
          unless revoked.include?(name) || reasons.all?(revoked)
            [name, reasons - revoked.to_a]
          end
        end.to_h
      end

      OPTION_IMPLICATIONS = { # :nodoc:
        skip_active_job:     [:skip_action_mailer, :skip_active_storage],
        skip_active_record:  [:skip_active_storage],
        skip_active_storage: [:skip_action_mailbox, :skip_action_text],
        skip_javascript:     [:skip_hotwire],
      }

      # ==== Options
      #
      # [+:meta_options+]
      #   A list of generator options which only serve to trigger other options.
      #   These options should have no other effects, and will be treated
      #   transparently when revoking other options.
      #
      #   For example: --minimal implies both --skip-active-job and
      #   --skip-active-storage. Also, --skip-active-job by itself implies
      #   --skip-active-storage. If --skip-active-job is explicitly
      #   specified, --no-skip-active-storage should raise an error. But, if
      #   only --minimal is specified, --no-skip-active-storage should "undo"
      #   the implied --skip-active-job. This can be accomplished by passing
      #   <tt>meta_options: [:minimal]</tt>.
      #
      #   In contrast, --api is not a meta option because it does other things
      #   besides implying options such as --skip-asset-pipeline. (And so --api
      #   with --no-skip-asset-pipeline should raise an error.)
      def imply_options(option_implications = OPTION_IMPLICATIONS, meta_options: [])
        option_reasons = {}
        option_implications.each do |reason, implications|
          implications.each do |implication|
            (option_reasons[implication.to_s] ||= []) << reason.to_s
          end
        end

        @implied_options = deduce_implied_options(options, option_reasons, meta_options.map(&:to_s))
        @implied_options_conflicts = @implied_options.keys.select { |name| options[name] == false }
        self.options = options.merge(@implied_options.transform_values { true }).freeze
      end

      def report_implied_options
        return if @implied_options.blank?

        say "Based on the specified options, the following options will also be activated:"
        say ""
        @implied_options.each do |name, reasons|
          due_to = reasons.map { |reason| "--#{reason.dasherize}" }.join(", ")
          say "  --#{name.dasherize} [due to #{due_to}]"
          if @implied_options_conflicts.include?(name)
            say "    ERROR: Conflicts with --no-#{name.dasherize}", :red
          end
        end
        say ""

        raise "Cannot proceed due to conflicting options" if @implied_options_conflicts.any?
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

        if options[:template].is_a?(String) && !options[:template].match?(/^https?:\/\//)
          interpolated = options[:template].gsub(/\$(\w+)|\$\{\g<1>\}|%\g<1>%/) { |m| ENV[$1] || m }
          self.rails_template = File.expand_path(interpolated)
        else
          self.rails_template = options[:template]
        end
      end

      def database_gemfile_entry # :doc:
        return if options[:skip_active_record]

        gem_name, gem_version = gem_for_database
        GemfileEntry.version gem_name, gem_version,
          "Use #{options[:database]} as the database for Active Record"
      end

      def web_server_gemfile_entry # :doc:
        GemfileEntry.new "puma", ">= 5.0", "Use the Puma web server [https://github.com/puma/puma]"
      end

      def asset_pipeline_gemfile_entry
        return if skip_asset_pipeline?

        if options[:asset_pipeline] == "sprockets"
          GemfileEntry.floats "sprockets-rails",
            "The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]"
        elsif options[:asset_pipeline] == "propshaft"
          GemfileEntry.floats "propshaft", "The modern asset pipeline for Rails [https://github.com/rails/propshaft]"
        end
      end

      def required_railties
        @required_railties ||= {
          "active_model/railtie"      => true,
          "active_job/railtie"        => !options[:skip_active_job],
          "active_record/railtie"     => !options[:skip_active_record],
          "active_storage/engine"     => !options[:skip_active_storage],
          "action_controller/railtie" => true,
          "action_mailer/railtie"     => !options[:skip_action_mailer],
          "action_mailbox/engine"     => !options[:skip_action_mailbox],
          "action_text/engine"        => !options[:skip_action_text],
          "action_view/railtie"       => true,
          "action_cable/engine"       => !options[:skip_action_cable],
          "rails/test_unit/railtie"   => !options[:skip_test],
        }
      end

      def include_all_railties? # :doc:
        required_railties.values.all?
      end

      def rails_require_statement
        if include_all_railties?
          %(require "rails/all")
        else
          require_statements = required_railties.map do |railtie, required|
            %(#{"# " if !required}require "#{railtie}")
          end

          <<~RUBY.strip
            require "rails"
            # Pick the frameworks you want:
            #{require_statements.join("\n")}
          RUBY
        end
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
        !skip_active_record? && options[:database] == "sqlite3"
      end

      def skip_active_record? # :doc:
        options[:skip_active_record]
      end

      def skip_active_storage? # :doc:
        options[:skip_active_storage]
      end

      def skip_action_cable? # :doc:
        options[:skip_action_cable]
      end

      def skip_action_mailer? # :doc:
        options[:skip_action_mailer]
      end

      def skip_action_mailbox? # :doc:
        options[:skip_action_mailbox]
      end

      def skip_action_text? # :doc:
        options[:skip_action_text]
      end

      def skip_asset_pipeline? # :doc:
        options[:skip_asset_pipeline]
      end

      def skip_sprockets?
        skip_asset_pipeline? || options[:asset_pipeline] != "sprockets"
      end

      def skip_propshaft?
        skip_asset_pipeline? || options[:asset_pipeline] != "propshaft"
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

      def gem_ruby_version
        Gem::Version.new(Gem::VERSION) >= Gem::Version.new("3.3.13") ? Gem.ruby_version : RUBY_VERSION
      end

      def rails_prerelease?
        options.dev? || options.edge? || options.main?
      end

      def rails_gemfile_entry
        if options.dev?
          GemfileEntry.path("rails", Rails::Generators::RAILS_DEV_PATH, "Use local checkout of Rails")
        elsif options.edge?
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

        if options[:javascript] == "importmap"
          GemfileEntry.floats "importmap-rails", "Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]"
        else
          GemfileEntry.floats "jsbundling-rails", "Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]"
        end
      end

      def hotwire_gemfile_entry
        return if options[:skip_hotwire]

        turbo_rails_entry =
          GemfileEntry.floats "turbo-rails", "Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]"

        stimulus_rails_entry =
          GemfileEntry.floats "stimulus-rails", "Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]"

        [ turbo_rails_entry, stimulus_rails_entry ]
      end

      def using_js_runtime?
        (options[:javascript] && !%w[importmap].include?(options[:javascript])) ||
          (options[:css] && !%w[tailwind sass].include?(options[:css]))
      end

      def using_node?
        using_js_runtime? && !%w[bun].include?(options[:javascript])
      end

      def using_bun?
        using_js_runtime? && %w[bun].include?(options[:javascript])
      end

      def node_version
        if using_node?
          ENV.fetch("NODE_VERSION") do
            `node --version`[/\d+\.\d+\.\d+/]
          rescue
            NODE_LTS_VERSION
          end
        end
      end

      def dockerfile_yarn_version
        using_node? and `yarn --version`[/\d+\.\d+\.\d+/]
      rescue
        "latest"
      end

      def dockerfile_bun_version
        using_bun? and `bun --version`[/\d+\.\d+\.\d+/]
      rescue
        BUN_VERSION
      end

      def dockerfile_binfile_fixups
        # binfiles may have OS specific paths to ruby.  Normalize them.
        shebangs = Dir["bin/*"].map { |file| IO.read(file).lines.first }.join
        rubies = shebangs.scan(%r{#!/usr/bin/env (ruby.*)}).flatten.uniq

        binfixups = (rubies - %w(ruby)).map do |ruby|
          "sed -i 's/#{Regexp.quote(ruby)}$/ruby/' bin/*"
        end

        # Windows line endings will cause scripts to fail.  If any
        # or found OR this generation is run on a windows platform
        # and there are other binfixups required, then convert
        # line endings.  This avoids adding unnecessary fixups if
        # none are required, but prepares for the need to do the
        # fix line endings if other fixups are required.
        has_cr = Dir["bin/*"].any? { |file| IO.read(file).include? "\r" }
        if has_cr || (Gem.win_platform? && !binfixups.empty?)
          binfixups.unshift 'sed -i "s/\r$//g" bin/*'
        end

        # Windows file systems may not have the concept of executable.
        # In such cases, fix up during the build.
        unless Dir["bin/*"].all? { |file| File.executable? file }
          binfixups.unshift "chmod +x bin/*"
        end

        binfixups
      end

      def dockerfile_build_packages
        # start with the essentials
        packages = %w(build-essential git pkg-config)

        # add database support
        packages << build_package_for_database unless skip_active_record?

        # ActiveStorage preview support
        packages << "libvips" unless skip_active_storage?

        packages << "curl" if using_js_runtime?

        packages << "unzip" if using_bun?

        # node support, including support for building native modules
        if using_node?
          packages << "node-gyp" # pkg-config already listed above

          # module build process depends on Python, and debian changed
          # how python is installed with the bullseye release.  Below
          # is based on debian release included with the Ruby images on
          # Dockerhub.
          case Gem.ruby_version.to_s
          when /^2\.7/
            bullseye = Gem.ruby_version >= Gem::Version.new("2.7.4")
          when /^3\.0/
            bullseye = Gem.ruby_version >= Gem::Version.new("3.0.2")
          else
            bullseye = true
          end

          if bullseye
            packages << "python-is-python3"
          else
            packages << "python"
          end
        end

        packages.compact.sort
      end

      def dockerfile_deploy_packages
        # Add curl to work with the default healthcheck strategy in Kamal
        packages = ["curl"]

        # ActiveRecord databases
        packages << deploy_package_for_database unless skip_active_record?

        # ActiveStorage preview support
        packages << "libvips" unless skip_active_storage?

        packages.compact.sort
      end

      def css_gemfile_entry
        return unless options[:css]

        if !using_js_runtime? && options[:css] == "tailwind"
          GemfileEntry.floats "tailwindcss-rails", "Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]"
        elsif !using_js_runtime? && options[:css] == "sass"
          GemfileEntry.floats "dartsass-rails", "Use Dart SASS [https://github.com/rails/dartsass-rails]"
        else
          GemfileEntry.floats "cssbundling-rails", "Bundle and process CSS [https://github.com/rails/cssbundling-rails]"
        end
      end

      def cable_gemfile_entry
        return if options[:skip_action_cable]

        comment = "Use Redis adapter to run Action Cable in production"
        GemfileEntry.new("redis", ">= 4.0.1", comment, {}, true)
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

      def bundler_windows_platforms
        Gem.rubygems_version >= Gem::Version.new("3.3.22") ? "windows" : "mswin mswin64 mingw x64_mingw"
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

          @argv.delete_at(@argv.index(app_path))
          @argv.unshift(destination_root)
          require "shellwords"
          bundle_command("exec rails #{self_command} #{Shellwords.join(@argv)}")
          exit
        else
          remove_file("Gemfile")
          remove_file("Gemfile.lock")
        end
      end

      def run_bundle
        if bundle_install?
          bundle_command("install", "BUNDLE_IGNORE_MESSAGES" => "1")

          # The vast majority of Rails apps will be deployed on `x86_64-linux`.
          platforms = ["--add-platform=x86_64-linux"]

          # Users that develop on M1 mac may use docker and would need `aarch64-linux` as well.
          platforms << "--add-platform=aarch64-linux" if RUBY_PLATFORM.start_with?("arm64")

          platforms.each do |platform|
            bundle_command("lock #{platform}", "BUNDLE_IGNORE_MESSAGES" => "1")
          end
        end
      end

      def run_javascript
        return if options[:skip_javascript] || !bundle_install?

        case options[:javascript]
        when "importmap"                           then rails_command "importmap:install"
        when "webpack", "bun", "esbuild", "rollup" then rails_command "javascript:install:#{options[:javascript]}"
        end
      end

      def run_hotwire
        return if options[:skip_hotwire] || !bundle_install?

        rails_command "turbo:install stimulus:install"
      end

      def run_css
        return if !options[:css] || !bundle_install?

        if !using_js_runtime? && options[:css] == "tailwind"
          rails_command "tailwindcss:install"
        elsif !using_js_runtime? && options[:css] == "sass"
          rails_command "dartsass:install"
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

      def edge_branch
        self.class.edge_branch
      end

      def dockerfile_chown_directories
        directories = %w(log tmp)

        directories << "storage" unless skip_active_storage? && !sqlite3?
        directories << "db" unless skip_active_record?

        directories.sort
      end
    end
  end
end
