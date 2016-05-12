require 'fileutils'
require 'digest/md5'
require 'active_support/core_ext/string/strip'
require 'rails/version' unless defined?(Rails::VERSION)
require 'open-uri'
require 'uri'
require 'rails/generators'
require 'active_support/core_ext/array/extract_options'

module Rails
  module Generators
    class AppBase < Base # :nodoc:
      DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver )
      JDBC_DATABASES = %w( jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc )
      DATABASES.concat(JDBC_DATABASES)

      attr_accessor :rails_template
      add_shebang_option!

      argument :app_path, type: :string

      def self.strict_args_position
        false
      end

      def self.add_shared_options_for(name)
        class_option :template,           type: :string, aliases: '-m',
                                          desc: "Path to some #{name} template (can be a filesystem path or URL)"

        class_option :database,           type: :string, aliases: '-d', default: 'sqlite3',
                                          desc: "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :javascript,         type: :string, aliases: '-j', default: 'jquery',
                                          desc: 'Preconfigure for selected JavaScript library'

        class_option :skip_gemfile,       type: :boolean, default: false,
                                          desc: "Don't create a Gemfile"

        class_option :skip_bundle,        type: :boolean, aliases: '-B', default: false,
                                          desc: "Don't run bundle install"

        class_option :skip_git,           type: :boolean, aliases: '-G', default: false,
                                          desc: 'Skip .gitignore file'

        class_option :skip_keeps,         type: :boolean, default: false,
                                          desc: 'Skip source control .keep files'

        class_option :skip_action_mailer, type: :boolean, aliases: "-M",
                                          default: false,
                                          desc: "Skip Action Mailer files"

        class_option :skip_active_record, type: :boolean, aliases: '-O', default: false,
                                          desc: 'Skip Active Record files'

        class_option :skip_puma,          type: :boolean, aliases: '-P', default: false,
                                          desc: 'Skip Puma related files'

        class_option :skip_action_cable,  type: :boolean, aliases: '-C', default: false,
                                          desc: 'Skip Action Cable files'

        class_option :skip_sprockets,     type: :boolean, aliases: '-S', default: false,
                                          desc: 'Skip Sprockets files'

        class_option :skip_spring,        type: :boolean, default: false,
                                          desc: "Don't install Spring application preloader"

        class_option :skip_listen,        type: :boolean, default: false,
                                          desc: "Don't generate configuration that depends on the listen gem"

        class_option :skip_javascript,    type: :boolean, aliases: '-J', default: false,
                                          desc: 'Skip JavaScript files'

        class_option :skip_turbolinks,    type: :boolean, default: false,
                                          desc: 'Skip turbolinks gem'

        class_option :skip_test,          type: :boolean, aliases: '-T', default: false,
                                          desc: 'Skip test files'

        class_option :dev,                type: :boolean, default: false,
                                          desc: "Setup the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,               type: :boolean, default: false,
                                          desc: "Setup the #{name} with Gemfile pointing to Rails repository"

        class_option :rc,                 type: :string, default: nil,
                                          desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,              type: :boolean, default: false,
                                          desc: 'Skip loading of extra configuration options from .railsrc file'

        class_option :help,               type: :boolean, aliases: '-h', group: :rails,
                                          desc: 'Show this help message and quit'
      end

      def initialize(*args)
        @gem_filter    = lambda { |gem| true }
        @extra_entries = []
        super
        convert_database_option_for_jruby
      end

    protected

      def gemfile_entry(name, *args)
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

      def gemfile_entries
        [rails_gemfile_entries,
         database_gemfile_entry,
         webserver_gemfile_entry,
         assets_gemfile_entry,
         javascript_gemfile_entry,
         jbuilder_gemfile_entry,
         psych_gemfile_entry,
         cable_gemfile_entry,
         @extra_entries].flatten.find_all(&@gem_filter)
      end

      def add_gem_entry_filter
        @gem_filter = lambda { |next_filter, entry|
          yield(entry) && next_filter.call(entry)
        }.curry[@gem_filter]
      end

      def builder
        @builder ||= begin
          builder_class = get_builder_class
          builder_class.include(ActionMethods)
          builder_class.new(self)
        end
      end

      def build(meth, *args)
        builder.send(meth, *args) if builder.respond_to?(meth)
      end

      def create_root
        valid_const?

        empty_directory '.'
        FileUtils.cd(destination_root) unless options[:pretend]
      end

      def apply_rails_template
        apply rails_template if rails_template
      rescue Thor::Error, LoadError, Errno::ENOENT => e
        raise Error, "The template [#{rails_template}] could not be loaded. Error: #{e}"
      end

      def set_default_accessors!
        self.destination_root = File.expand_path(app_path, destination_root)
        self.rails_template = case options[:template]
          when /^https?:\/\//
            options[:template]
          when String
            File.expand_path(options[:template], Dir.pwd)
          else
            options[:template]
        end
      end

      def database_gemfile_entry
        return [] if options[:skip_active_record]
        gem_name, gem_version = gem_for_database
        GemfileEntry.version gem_name, gem_version,
                            "Use #{options[:database]} as the database for Active Record"
      end

      def webserver_gemfile_entry
        return [] if options[:skip_puma]
        comment = 'Use Puma as the app server'
        GemfileEntry.new('puma', '~> 3.0', comment)
      end

      def include_all_railties?
        options.values_at(:skip_active_record, :skip_action_mailer, :skip_test, :skip_sprockets, :skip_action_cable).none?
      end

      def comment_if(value)
        options[value] ? '# ' : ''
      end

      def keeps?
        !options[:skip_keeps]
      end

      def sqlite3?
        !options[:skip_active_record] && options[:database] == 'sqlite3'
      end

      class GemfileEntry < Struct.new(:name, :version, :comment, :options, :commented_out)
        def initialize(name, version, comment, options = {}, commented_out = false)
          super
        end

        def self.github(name, github, branch = nil, comment = nil, commented_out = false)
          options = branch ? {github: github, branch: branch} : {github: github}
          new(name, nil, comment, options, commented_out)
        end

        def self.version(name, version, comment = nil, commented_out = false)
          new(name, version, comment, {}, commented_out)
        end

        def self.path(name, path, comment = nil, commented_out = false)
          new(name, nil, comment, {path: path}, commented_out)
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

      def rails_gemfile_entries
        skips = %i(skip_action_cable skip_action_mailer skip_active_record)
        components_to_skip = options.slice(*skips).select{|_,v| v}
        if components_to_skip.any?
          rails_gemfile_entry_skipping components_to_skip
        else
          rails_gemfile_entry
        end
      end

      def rails_gemfile_entry(gem_name = 'rails', commented_out: false)
        dev_edge_common = [
        ]
        if options.dev?
          [
            GemfileEntry.path(gem_name, Rails::Generators::RAILS_DEV_PATH, nil, commented_out)
          ] + dev_edge_common
        elsif options.edge?
          [
            GemfileEntry.github(gem_name, "rails/#{gem_name}", nil, nil, commented_out)
          ] + dev_edge_common
        elsif gem_name == 'rails'
          [GemfileEntry.version(gem_name,
                            rails_version_specifier,
                            "Bundle edge Rails instead: gem '#{gem_name}', github: 'rails/#{gem_name}'", commented_out)]
        else
          [GemfileEntry.version(gem_name, rails_version_specifier, nil, commented_out)]
        end
      end

      def rails_gemfile_entry_skipping(components_to_skip)
        gems = rails_gemfile_entry('rails', commented_out: true)

        skip = components_to_skip.key? 'skip_action_cable'
        gems << rails_gemfile_entry('actioncable', commented_out: skip)

        skip = components_to_skip.key? 'skip_action_mailer'
        gems << rails_gemfile_entry('actionmailer', commented_out: skip)

        gems << rails_gemfile_entry('activejob', commented_out: false)

        gems << rails_gemfile_entry('activemodel', commented_out: false)

        skip = components_to_skip.key? 'skip_active_record'
        gems << rails_gemfile_entry('activerecord', commented_out: skip)

        gems << rails_gemfile_entry('railties', commented_out: false)

        gems
      end

      def rails_version_specifier(gem_version = Rails.gem_version)
        if gem_version.prerelease?
          next_series = gem_version
          next_series = next_series.bump while next_series.segments.size > 2

          [">= #{gem_version}", "< #{next_series}"]
        elsif gem_version.segments.size == 3
          "~> #{gem_version}"
        else
          patch = gem_version.segments[0, 3].join(".")
          ["~> #{patch}", ">= #{gem_version}"]
        end
      end

      def gem_for_database
        # %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver jdbcmysql jdbcsqlite3 jdbcpostgresql )
        case options[:database]
        when "oracle"         then ["ruby-oci8", nil]
        when "postgresql"     then ["pg", ["~> 0.18"]]
        when "frontbase"      then ["ruby-frontbase", nil]
        when "mysql"          then ["mysql2", [">= 0.3.18", "< 0.5"]]
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
          case options[:database]
          when "oracle"     then options[:database].replace "jdbc"
          when "postgresql" then options[:database].replace "jdbcpostgresql"
          when "mysql"      then options[:database].replace "jdbcmysql"
          when "sqlite3"    then options[:database].replace "jdbcsqlite3"
          end
        end
      end

      def assets_gemfile_entry
        return [] if options[:skip_sprockets]

        gems = []
        gems << GemfileEntry.github('sass-rails', 'rails/sass-rails', nil,
                                     'Use SCSS for stylesheets')

        gems << GemfileEntry.version('uglifier',
                                   '>= 1.3.0',
                                   'Use Uglifier as compressor for JavaScript assets')

        gems
      end

      def jbuilder_gemfile_entry
        comment = 'Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder'
        GemfileEntry.new 'jbuilder', '~> 2.0', comment, {}, options[:api]
      end

      def coffee_gemfile_entry
        GemfileEntry.github 'coffee-rails', 'rails/coffee-rails', nil, 'Use CoffeeScript for .coffee assets and views'
      end

      def javascript_gemfile_entry
        if options[:skip_javascript] || options[:skip_sprockets]
          []
        else
          gems = [coffee_gemfile_entry, javascript_runtime_gemfile_entry]
          gems << GemfileEntry.version("#{options[:javascript]}-rails", nil,
                                       "Use #{options[:javascript]} as the JavaScript library")

          unless options[:skip_turbolinks]
            gems << GemfileEntry.version("turbolinks", "~> 5.x",
             "Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks")
          end

          gems
        end
      end

      def javascript_runtime_gemfile_entry
        comment = 'See https://github.com/rails/execjs#readme for more supported runtimes'
        if defined?(JRUBY_VERSION)
          GemfileEntry.version 'therubyrhino', nil, comment
        else
          GemfileEntry.new 'therubyracer', nil, comment, { platforms: :ruby }, true
        end
      end

      def psych_gemfile_entry
        return [] unless defined?(Rubinius)

        comment = 'Use Psych as the YAML engine, instead of Syck, so serialized ' \
                  'data can be read safely from different rubies (see http://git.io/uuLVag)'
        GemfileEntry.new('psych', '~> 2.0', comment, platforms: :rbx)
      end

      def cable_gemfile_entry
        return [] if options[:skip_action_cable]
        comment = 'Use Redis adapter to run Action Cable in production'
        gems = []
        gems << GemfileEntry.new("redis", '~> 3.0', comment, {}, true)
        gems
      end

      def bundle_command(command)
        say_status :run, "bundle #{command}"

        # We are going to shell out rather than invoking Bundler::CLI.new(command)
        # because `rails new` loads the Thor gem and on the other hand bundler uses
        # its own vendored Thor, which could be a different version. Running both
        # things in the same process is a recipe for a night with paracetamol.
        #
        # We unset temporary bundler variables to load proper bundler and Gemfile.
        #
        # Thanks to James Tucker for the Gem tricks involved in this call.
        _bundle_command = Gem.bin_path('bundler', 'bundle')

        require 'bundler'
        Bundler.with_clean_env do
          full_command = %Q["#{Gem.ruby}" "#{_bundle_command}" #{command}]
          if options[:quiet]
            system(full_command, out: File::NULL)
          else
            system(full_command)
          end
        end
      end

      def bundle_install?
        !(options[:skip_gemfile] || options[:skip_bundle] || options[:pretend])
      end

      def spring_install?
        !options[:skip_spring] && !options.dev? && Process.respond_to?(:fork) && !RUBY_PLATFORM.include?("cygwin")
      end

      def depend_on_listen?
        !options[:skip_listen] && os_supports_listen_out_of_the_box?
      end

      def os_supports_listen_out_of_the_box?
        RbConfig::CONFIG['host_os'] =~ /darwin|linux/
      end

      def run_bundle
        bundle_command('install') if bundle_install?
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
