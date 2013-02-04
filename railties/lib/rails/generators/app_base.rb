require 'digest/md5'
require 'securerandom'
require 'active_support/core_ext/string/strip'
require 'rails/version' unless defined?(Rails::VERSION)
require 'rbconfig'
require 'open-uri'
require 'uri'

module Rails
  module Generators
    class AppBase < Base # :nodoc:
      DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver )
      JDBC_DATABASES = %w( jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc )
      DATABASES.concat(JDBC_DATABASES)

      attr_accessor :rails_template
      add_shebang_option!

      argument :app_path, type: :string

      def self.add_shared_options_for(name)
        class_option :builder,            type: :string, aliases: '-b',
                                          desc: "Path to a #{name} builder (can be a filesystem path or URL)"

        class_option :template,           type: :string, aliases: '-m',
                                          desc: "Path to an #{name} template (can be a filesystem path or URL)"

        class_option :skip_gemfile,       type: :boolean, default: false,
                                          desc: "Don't create a Gemfile"

        class_option :skip_bundle,        type: :boolean, aliases: '-B', default: false,
                                          desc: "Don't run bundle install"

        class_option :skip_git,           type: :boolean, aliases: '-G', default: false,
                                          desc: 'Skip .gitignore file'

        class_option :skip_keeps,         type: :boolean, default: false,
                                          desc: 'Skip source control .keep files'

        class_option :skip_active_record, type: :boolean, aliases: '-O', default: false,
                                          desc: 'Skip Active Record files'

        class_option :skip_sprockets,     type: :boolean, aliases: '-S', default: false,
                                          desc: 'Skip Sprockets files'

        class_option :database,           type: :string, aliases: '-d', default: 'sqlite3',
                                          desc: "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :javascript,         type: :string, aliases: '-j', default: 'jquery',
                                          desc: 'Preconfigure for selected JavaScript library'

        class_option :skip_javascript,    type: :boolean, aliases: '-J', default: false,
                                          desc: 'Skip JavaScript files'

        class_option :dev,                type: :boolean, default: false,
                                          desc: "Setup the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,               type: :boolean, default: false,
                                          desc: "Setup the #{name} with Gemfile pointing to Rails repository"

        class_option :skip_test_unit,     type: :boolean, aliases: '-T', default: false,
                                          desc: 'Skip Test::Unit files'

        class_option :rc,                 type: :string, default: false,
                                          desc: "Path to file containing extra configuration options for rails command"

        class_option :no_rc,              type: :boolean, default: false,
                                          desc: 'Skip loading of extra configuration options from .railsrc file'

        class_option :help,               type: :boolean, aliases: '-h', group: :rails,
                                          desc: 'Show this help message and quit'
      end

      def initialize(*args)
        @original_wd = Dir.pwd
        super
        convert_database_option_for_jruby
      end

    protected

      def builder
        @builder ||= begin
          if path = options[:builder]
            if URI(path).is_a?(URI::HTTP)
              contents = open(path, "Accept" => "application/x-thor-template") {|io| io.read }
            else
              contents = open(File.expand_path(path, @original_wd)) {|io| io.read }
            end

            prok = eval("proc { #{contents} }", TOPLEVEL_BINDING, path, 1)
            instance_eval(&prok)
          end

          builder_class = get_builder_class
          builder_class.send(:include, ActionMethods)
          builder_class.new(self)
        end
      end

      def build(meth, *args)
        builder.send(meth, *args) if builder.respond_to?(meth)
      end

      def create_root
        self.destination_root = File.expand_path(app_path, destination_root)
        valid_const?

        empty_directory '.'
        set_default_accessors!
        FileUtils.cd(destination_root) unless options[:pretend]
      end

      def apply_rails_template
        apply rails_template if rails_template
      rescue Thor::Error, LoadError, Errno::ENOENT => e
        raise Error, "The template [#{rails_template}] could not be loaded. Error: #{e}"
      end

      def set_default_accessors!
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
        options[:skip_active_record] ? "" : "gem '#{gem_for_database}'"
      end

      def include_all_railties?
        !options[:skip_active_record] && !options[:skip_test_unit] && !options[:skip_sprockets]
      end

      def comment_if(value)
        options[value] ? '# ' : ''
      end

      def rails_gemfile_entry
        if options.dev?
          <<-GEMFILE.strip_heredoc
            gem 'rails',     path: '#{Rails::Generators::RAILS_DEV_PATH}'
            gem 'arel',      github: 'rails/arel'
            gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders'
          GEMFILE
        elsif options.edge?
          <<-GEMFILE.strip_heredoc
            gem 'rails',     github: 'rails/rails'
            gem 'arel',      github: 'rails/arel'
            gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders'
          GEMFILE
        else
          <<-GEMFILE.strip_heredoc
            # Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
            gem 'rails', '#{Rails::VERSION::STRING}'
          GEMFILE
        end
      end

      def gem_for_database
        # %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver jdbcmysql jdbcsqlite3 jdbcpostgresql )
        case options[:database]
        when "oracle"         then "ruby-oci8"
        when "postgresql"     then "pg"
        when "frontbase"      then "ruby-frontbase"
        when "mysql"          then "mysql2"
        when "sqlserver"      then "activerecord-sqlserver-adapter"
        when "jdbcmysql"      then "activerecord-jdbcmysql-adapter"
        when "jdbcsqlite3"    then "activerecord-jdbcsqlite3-adapter"
        when "jdbcpostgresql" then "activerecord-jdbcpostgresql-adapter"
        when "jdbc"           then "activerecord-jdbc-adapter"
        else options[:database]
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
        return if options[:skip_sprockets]

        gemfile = if options.dev? || options.edge?
          <<-GEMFILE
            # Gems used only for assets and not required
            # in production environments by default.
            group :assets do
              gem 'sprockets-rails', github: 'rails/sprockets-rails'
              gem 'sass-rails',   github: 'rails/sass-rails'
              gem 'coffee-rails', github: 'rails/coffee-rails'

              # See https://github.com/sstephenson/execjs#readme for more supported runtimes
              #{javascript_runtime_gemfile_entry}
              gem 'uglifier', '>= 1.0.3'
            end
          GEMFILE
        else
          <<-GEMFILE
            # Gems used only for assets and not required
            # in production environments by default.
            group :assets do
              gem 'sprockets-rails', '~> 2.0.0.rc1'
              gem 'sass-rails',   '~> 4.0.0.beta'
              gem 'coffee-rails', '~> 4.0.0.beta'

              # See https://github.com/sstephenson/execjs#readme for more supported runtimes
              #{javascript_runtime_gemfile_entry}
              gem 'uglifier', '>= 1.0.3'
            end
          GEMFILE
        end

        gemfile.strip_heredoc.gsub(/^[ \t]*$/, '')
      end

      def javascript_gemfile_entry
        unless options[:skip_javascript]
          <<-GEMFILE.strip_heredoc
            gem '#{options[:javascript]}-rails'

            # Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
            gem 'turbolinks'
          GEMFILE
        end
      end

      def javascript_runtime_gemfile_entry
        if defined?(JRUBY_VERSION)
          "gem 'therubyrhino'\n"
        else
          "# gem 'therubyracer', platforms: :ruby\n"
        end
      end

      def bundle_command(command)
        say_status :run, "bundle #{command}"

        # We are going to shell out rather than invoking Bundler::CLI.new(command)
        # because `rails new` loads the Thor gem and on the other hand bundler uses
        # its own vendored Thor, which could be a different version. Running both
        # things in the same process is a recipe for a night with paracetamol.
        #
        # We use backticks and #print here instead of vanilla #system because it
        # is easier to silence stdout in the existing test suite this way. The
        # end-user gets the bundler commands called anyway, so no big deal.
        #
        # We unset temporary bundler variables to load proper bundler and Gemfile.
        #
        # Thanks to James Tucker for the Gem tricks involved in this call.
        _bundle_command = Gem.bin_path('bundler', 'bundle')

        require 'bundler'
        Bundler.with_clean_env do
          print `"#{Gem.ruby}" "#{_bundle_command}" #{command}`
        end
      end

      def run_bundle
        bundle_command('install') unless options[:skip_gemfile] || options[:skip_bundle] || options[:pretend]
      end

      def empty_directory_with_keep_file(destination, config = {})
        empty_directory(destination, config)
        keep_file(destination)
      end

      def keep_file(destination)
        create_file("#{destination}/.keep") unless options[:skip_keeps]
      end
    end
  end
end
