require 'digest/md5'
require 'active_support/secure_random'
require 'active_support/core_ext/string/strip'
require 'rails/version' unless defined?(Rails::VERSION)
require 'rbconfig'
require 'open-uri'
require 'uri'

module Rails
  module Generators
    class AppBase < Base
      DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver )
      JDBC_DATABASES = %w( jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc )
      DATABASES.concat(JDBC_DATABASES)

      attr_accessor :rails_template
      add_shebang_option!

      argument :app_path,               :type => :string

      def self.add_shared_options_for(name)
        class_option :builder,            :type => :string, :aliases => "-b",
                                          :desc => "Path to a #{name} builder (can be a filesystem path or URL)"

        class_option :template,           :type => :string, :aliases => "-m",
                                          :desc => "Path to an #{name} template (can be a filesystem path or URL)"

        class_option :skip_gemfile,       :type => :boolean, :default => false,
                                          :desc => "Don't create a Gemfile"

        class_option :skip_bundle,        :type => :boolean, :default => false,
                                          :desc => "Don't run bundle install"

        class_option :skip_git,           :type => :boolean, :aliases => "-G", :default => false,
                                          :desc => "Skip Git ignores and keeps"

        class_option :skip_active_record, :type => :boolean, :aliases => "-O", :default => false,
                                          :desc => "Skip Active Record files"

        class_option :skip_sprockets,     :type => :boolean, :aliases => "-S", :default => false,
                                          :desc => "Skip Sprockets files"

        class_option :database,           :type => :string, :aliases => "-d", :default => "sqlite3",
                                          :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :javascript,         :type => :string, :aliases => '-j', :default => 'jquery',
                                          :desc => 'Preconfigure for selected JavaScript library'

        class_option :skip_javascript,    :type => :boolean, :aliases => "-J", :default => false,
                                          :desc => "Skip JavaScript files"

        class_option :dev,                :type => :boolean, :default => false,
                                          :desc => "Setup the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,               :type => :boolean, :default => false,
                                          :desc => "Setup the #{name} with Gemfile pointing to Rails repository"

        class_option :skip_test_unit,     :type => :boolean, :aliases => "-T", :default => false,
                                          :desc => "Skip Test::Unit files"

        class_option :help,               :type => :boolean, :aliases => "-h", :group => :rails,
                                          :desc => "Show this help message and quit"

        class_option :old_style_hash,     :type => :boolean, :default => false,
                                          :desc => "Force using old style hash (:foo => 'bar') on Ruby >= 1.9"
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
        options[:skip_active_record] ? "" : "gem '#{gem_for_database}'\n"
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
            gem 'rails',     :path => '#{Rails::Generators::RAILS_DEV_PATH}'
          GEMFILE
        elsif options.edge?
          <<-GEMFILE.strip_heredoc
            gem 'rails',     :git => 'git://github.com/rails/rails.git'
          GEMFILE
        else
          <<-GEMFILE.strip_heredoc
            gem 'rails', '#{Rails::VERSION::STRING}'

            # Bundle edge Rails instead:
            # gem 'rails',     :git => 'git://github.com/rails/rails.git'
          GEMFILE
        end
      end

      def gem_for_database
        # %w( mysql oracle postgresql sqlite3 frontbase ibm_db sqlserver jdbcmysql jdbcsqlite3 jdbcpostgresql )
        case options[:database]
        when "oracle"     then "ruby-oci8"
        when "postgresql" then "pg"
        when "frontbase"  then "ruby-frontbase"
        when "mysql"      then "mysql2"
        when "sqlserver"  then "activerecord-sqlserver-adapter"
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

      def ruby_debugger_gemfile_entry
        if RUBY_VERSION < "1.9"
          "gem 'ruby-debug'"
        else
          "gem 'ruby-debug19', :require => 'ruby-debug'"
        end
      end

      def turn_gemfile_entry
        unless RUBY_VERSION < "1.9.2" || options[:skip_test_unit]
          <<-GEMFILE.strip_heredoc
            group :test do
              # Pretty printed test output
              gem 'turn', :require => false
            end
          GEMFILE
        end
      end

      def javascript_gemfile_entry
        "gem '#{options[:javascript]}-rails'" unless options[:skip_javascript]
      end

      def assets_gemfile_entry
        <<-GEMFILE.strip_heredoc
          # Gems used only for assets and not required
          # in production environments by default.
          group :assets do
            gem 'sass-rails', #{options.dev? || options.edge? ? "  :git => 'git://github.com/rails/sass-rails.git', :branch => '3-1-stable'" : "  '~> 3.1.4'"}
            gem 'coffee-rails', #{options.dev? || options.edge? ? ":git => 'git://github.com/rails/coffee-rails.git', :branch => '3-1-stable'" : "'~> 3.1.1'"}
            gem 'uglifier', '>= 1.0.3'
          end
        GEMFILE
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
        # Thanks to James Tucker for the Gem tricks involved in this call.
        print `"#{Gem.ruby}" -rubygems "#{Gem.bin_path('bundler', 'bundle')}" #{command}`
      end

      def run_bundle
        bundle_command('install') unless options[:skip_gemfile] || options[:skip_bundle]
      end

      def empty_directory_with_gitkeep(destination, config = {})
        empty_directory(destination, config)
        git_keep(destination)
      end

      def git_keep(destination)
        create_file("#{destination}/.gitkeep") unless options[:skip_git]
      end

      # Returns Ruby 1.9 style key-value pair if current code is running on
      # Ruby 1.9.x. Returns the old-style (with hash rocket) otherwise.
      def key_value(key, value)
        if options[:old_style_hash] || RUBY_VERSION < '1.9'
          ":#{key} => #{value}"
        else
          "#{key}: #{value}"
        end
      end
    end
  end
end
