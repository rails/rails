require 'digest/md5'
require 'active_support/secure_random'
require 'rails/version' unless defined?(Rails::VERSION)
require 'rbconfig'
require 'open-uri'
require 'uri'

module Rails
  module Generators
    class AppBase < Base
      def self.say_step(message)
        @step = (@step || 0) + 1
        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def step_#{@step}
            #{"puts" if @step > 1}
            say_status "STEP #{@step}", #{message.inspect}
          end
        METHOD
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
          when /^http:\/\//
            options[:template]
          when String
            File.expand_path(options[:template], Dir.pwd)
          else
            options[:template]
        end
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

      def bundle_if_dev_or_edge
        bundle_command = File.basename(Thor::Util.ruby_command).sub(/ruby/, 'bundle')
        run "#{bundle_command} install" if dev_or_edge?
      end

      def dev_or_edge?
        options.dev? || options.edge?
      end
    end
  end
end
