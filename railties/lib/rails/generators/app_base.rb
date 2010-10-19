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
        FileUtils.cd(destination_root) unless options[:pretend]
      end
    end
  end
end
