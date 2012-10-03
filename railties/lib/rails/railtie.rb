require 'rails/initializable'
require 'rails/configuration'
require 'active_support/inflector'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/module/delegation'

module Rails
  # Railtie is the core of the Rails framework and provides several hooks to extend
  # Rails and/or modify the initialization process.
  #
  # Every major component of Rails (Action Mailer, Action Controller,
  # Action View and Active Record) is a Railtie. Each of
  # them is responsible for their own initialization. This makes Rails itself
  # absent of any component hooks, allowing other components to be used in
  # place of any of the Rails defaults.
  #
  # Developing a Rails extension does _not_ require any implementation of
  # Railtie, but if you need to interact with the Rails framework during
  # or after boot, then Railtie is needed.
  #
  # For example, an extension doing any of the following would require Railtie:
  #
  # * creating initializers
  # * configuring a Rails framework for the application, like setting a generator
  # * +adding config.*+ keys to the environment
  # * setting up a subscriber with ActiveSupport::Notifications
  # * adding rake tasks
  #
  # == Creating your Railtie
  #
  # To extend Rails using Railtie, create a Railtie class which inherits
  # from Rails::Railtie within your extension's namespace. This class must be
  # loaded during the Rails boot process.
  #
  # The following example demonstrates an extension which can be used with or without Rails.
  #
  #   # lib/my_gem/railtie.rb
  #   module MyGem
  #     class Railtie < Rails::Railtie
  #     end
  #   end
  #
  #   # lib/my_gem.rb
  #   require 'my_gem/railtie' if defined?(Rails)
  #
  # == Initializers
  #
  # To add an initialization step from your Railtie to Rails boot process, you just need
  # to create an initializer block:
  #
  #   class MyRailtie < Rails::Railtie
  #     initializer "my_railtie.configure_rails_initialization" do
  #       # some initialization behavior
  #     end
  #   end
  #
  # If specified, the block can also receive the application object, in case you
  # need to access some application specific configuration, like middleware:
  #
  #   class MyRailtie < Rails::Railtie
  #     initializer "my_railtie.configure_rails_initialization" do |app|
  #       app.middleware.use MyRailtie::Middleware
  #     end
  #   end
  #
  # Finally, you can also pass :before and :after as option to initializer, in case
  # you want to couple it with a specific step in the initialization process.
  #
  # == Configuration
  #
  # Inside the Railtie class, you can access a config object which contains configuration
  # shared by all railties and the application:
  #
  #   class MyRailtie < Rails::Railtie
  #     # Customize the ORM
  #     config.app_generators.orm :my_railtie_orm
  #
  #     # Add a to_prepare block which is executed once in production
  #     # and before each request in development
  #     config.to_prepare do
  #       MyRailtie.setup!
  #     end
  #   end
  #
  # == Loading rake tasks and generators
  #
  # If your railtie has rake tasks, you can tell Rails to load them through the method
  # rake_tasks:
  #
  #   class MyRailtie < Rails::Railtie
  #     rake_tasks do
  #       load "path/to/my_railtie.tasks"
  #     end
  #   end
  #
  # By default, Rails load generators from your load path. However, if you want to place
  # your generators at a different location, you can specify in your Railtie a block which
  # will load them during normal generators lookup:
  #
  #   class MyRailtie < Rails::Railtie
  #     generators do
  #       require "path/to/my_railtie_generator"
  #     end
  #   end
  #
  # == Application and Engine
  #
  # A Rails::Engine is nothing more than a Railtie with some initializers already set.
  # And since Rails::Application is an engine, the same configuration described here
  # can be used in both.
  #
  # Be sure to look at the documentation of those specific classes for more information.
  #
  class Railtie
    autoload :Configurable,  "rails/railtie/configurable"
    autoload :Configuration, "rails/railtie/configuration"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Railtie Rails::Engine Rails::Application)

    class << self
      private :new

      def subclasses
        @subclasses ||= []
      end

      def inherited(base)
        unless base.abstract_railtie?
          base.send(:include, Railtie::Configurable)
          subclasses << base
        end
      end

      def rake_tasks(&blk)
        @rake_tasks ||= []
        @rake_tasks << blk if blk
        @rake_tasks
      end

      def console(&blk)
        @load_console ||= []
        @load_console << blk if blk
        @load_console
      end

      def runner(&blk)
        @load_runner ||= []
        @load_runner << blk if blk
        @load_runner
      end

      def generators(&blk)
        @generators ||= []
        @generators << blk if blk
        @generators
      end

      def abstract_railtie?
        ABSTRACT_RAILTIES.include?(name)
      end

      def railtie_name(name = nil)
        @railtie_name = name.to_s if name
        @railtie_name ||= generate_railtie_name(self.name)
      end

      protected
        def generate_railtie_name(class_or_module)
          ActiveSupport::Inflector.underscore(class_or_module).tr("/", "_")
        end
    end

    delegate :railtie_name, :to => "self.class"

    def config
      @config ||= Railtie::Configuration.new
    end

    def railtie_namespace
      @railtie_namespace ||= self.class.parents.detect { |n| n.respond_to?(:railtie_namespace) }
    end

    protected

    def run_console_blocks(app) #:nodoc:
      self.class.console.each { |block| block.call(app) }
    end

    def run_generators_blocks(app) #:nodoc:
      self.class.generators.each { |block| block.call(app) }
    end

    def run_runner_blocks(app) #:nodoc:
      self.class.runner.each { |block| block.call(app) }
    end

    def run_tasks_blocks(app) #:nodoc:
      extend Rake::DSL
      self.class.rake_tasks.each { |block| instance_exec(app, &block) }

      # Load also tasks from all superclasses
      klass = self.class.superclass

      while klass.respond_to?(:rake_tasks)
        klass.rake_tasks.each { |t| instance_exec(app, &t) }
        klass = klass.superclass
      end
    end
  end
end
