require 'rails/initializable'
require 'rails/configuration'
require 'active_support/inflector'
require 'active_support/deprecation'

module Rails
  # Railtie is the core of the Rails Framework and provides several hooks to extend
  # Rails and/or modify the initialization process.
  #
  # Every major component of Rails (Action Mailer, Action Controller,
  # Action View, Active Record and Active Resource) are all Railties, so each of
  # them is responsible to set their own initialization. This makes, for example,
  # Rails absent of any Active Record hook, allowing any other ORM framework to hook in.
  #
  # Developing a Rails extension does _not_ require any implementation of
  # Railtie, but if you need to interact with the Rails framework during
  # or after boot, then Railtie is what you need to do that interaction.
  #
  # For example, the following would need you to implement Railtie in your
  # plugin:
  #
  # * creating initializers
  # * configuring a Rails framework or the Application, like setting a generator
  # * adding Rails config.* keys to the environment
  # * setting up a subscriber to the Rails +ActiveSupport::Notifications+
  # * adding rake tasks into rails
  #
  # == Creating your Railtie
  #
  # Implementing Railtie in your Rails extension is done by creating a class
  # Railtie that has your extension name and making sure that this gets loaded
  # during boot time of the Rails stack.
  #
  # You can do this however you wish, but here is an example if you want to provide
  # it for a gem that can be used with or without Rails:
  #
  # * Create a file (say, lib/my_gem/railtie.rb) which contains class Railtie inheriting from
  #   Rails::Railtie and is namespaced to your gem:
  #
  #     # lib/my_gem/railtie.rb
  #     module MyGem
  #       class Railtie < Rails::Railtie
  #       end
  #     end
  #
  # * Require your own gem as well as rails in this file:
  #
  #     # lib/my_gem/railtie.rb
  #     require 'my_gem'
  #     require 'rails'
  #
  #     module MyGem
  #       class Railtie < Rails::Railtie
  #       end
  #     end
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
  #     # and before which request in development
  #     config.to_prepare do
  #       MyRailtie.setup!
  #     end
  #   end
  #
  # == Loading rake tasks and generators
  #
  # If your railtie has rake tasks, you can tell Rails to load them through the method
  # rake tasks:
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
  # == Application, Plugin and Engine
  #
  # A Rails::Engine is nothing more than a Railtie with some initializers already set.
  # And since Rails::Application and Rails::Plugin are engines, the same configuration
  # described here can be used in all three.
  #
  # Be sure to look at the documentation of those specific classes for more information.
  #
  class Railtie
    autoload :Configurable,  "rails/railtie/configurable"
    autoload :Configuration, "rails/railtie/configuration"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Railtie Rails::Plugin Rails::Engine Rails::Application)

    class << self
      def subclasses
        @subclasses ||= []
      end

      def inherited(base)
        unless base.abstract_railtie?
          base.send(:include, self::Configurable)
          subclasses << base
        end
      end

      def railtie_name(*)
        ActiveSupport::Deprecation.warn "railtie_name is deprecated and has no effect", caller
      end

      def log_subscriber(*)
        ActiveSupport::Deprecation.warn "log_subscriber is deprecated and has no effect", caller
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

      def generators(&blk)
        @generators ||= []
        @generators << blk if blk
        @generators
      end

      def abstract_railtie?
        ABSTRACT_RAILTIES.include?(name)
      end
    end

    def eager_load!
    end

    def load_console
      self.class.console.each(&:call)
    end

    def load_tasks
      self.class.rake_tasks.each(&:call)
    end

    def load_generators
      self.class.generators.each(&:call)
    end
  end
end
