require 'digest/md5'
require 'active_support/secure_random'
require 'rails/version' unless defined?(Rails::VERSION)
require 'rbconfig'
require 'open-uri'
require 'uri'

module Rails
  module Generators
    class AppBase < Base
      DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db )
      JAVASCRIPTS = %w( prototype jquery )

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

        class_option :skip_git,           :type => :boolean, :aliases => "-G", :default => false,
                                          :desc => "Skip Git ignores and keeps"

        class_option :skip_active_record, :type => :boolean, :aliases => "-O", :default => false,
                                          :desc => "Skip Active Record files"

        class_option :database,           :type => :string, :aliases => "-d", :default => "sqlite3",
                                          :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

        class_option :javascript,         :type => :string, :aliases => "-j", :default => "prototype",
                                          :desc => "Preconfigure for selected javascript library (options: #{JAVASCRIPTS.join('/')})"

        class_option :skip_javascript,    :type => :boolean, :aliases => "-J", :default => false,
                                          :desc => "Skip javascript files"

        class_option :dev,                :type => :boolean, :default => false,
                                          :desc => "Setup the #{name} with Gemfile pointing to your Rails checkout"

        class_option :edge,               :type => :boolean, :default => false,
                                          :desc => "Setup the #{name} with Gemfile pointing to Rails repository"

        class_option :skip_test_unit,     :type => :boolean, :aliases => "-T", :default => false,
                                          :desc => "Skip Test::Unit files"

        class_option :help,               :type => :boolean, :aliases => "-h", :group => :rails,
                                          :desc => "Show this help message and quit"
      end

      def initialize(*args)
        @original_wd = Dir.pwd

        super
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

      def rails_gemfile_entry
        if options.dev?
          <<-GEMFILE
gem 'rails', :path => '#{Rails::Generators::RAILS_DEV_PATH}'
gem 'arel',  :git => 'git://github.com/rails/arel.git'
gem "rack", :git => "git://github.com/rack/rack.git"
          GEMFILE
        elsif options.edge?
          <<-GEMFILE
gem 'rails', :git => 'git://github.com/rails/rails.git'
gem 'arel',  :git => 'git://github.com/rails/arel.git'
gem "rack", :git => "git://github.com/rack/rack.git"
          GEMFILE
        else
          <<-GEMFILE
gem 'rails', '#{Rails::VERSION::STRING}'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'
# gem 'arel',  :git => 'git://github.com/rails/arel.git'
# gem "rack", :git => "git://github.com/rack/rack.git"
          GEMFILE
        end
      end

      def gem_for_database
        # %w( mysql oracle postgresql sqlite3 frontbase ibm_db )
        case options[:database]
        when "oracle"     then "ruby-oci8"
        when "postgresql" then "pg"
        when "frontbase"  then "ruby-frontbase"
        when "mysql"      then "mysql2"
        else options[:database]
        end
      end

      def bundle_if_dev_or_edge
        bundle_command = File.basename(Thor::Util.ruby_command).sub(/ruby/, 'bundle')
        run "#{bundle_command} install" if dev_or_edge?
      end

      def dev_or_edge?
        options.dev? || options.edge?
      end

      def empty_directory_with_gitkeep(destination, config = {})
        empty_directory(destination, config)
        create_file("#{destination}/.gitkeep") unless options[:skip_git]
      end

    end
  end
end
