require 'rails/initializable'
require 'rails/configuration'
require 'active_support/inflector'

module Rails
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

      def log_subscriber(name, log_subscriber)
        Rails::LogSubscriber.add(name, log_subscriber)
      end

      def rake_tasks(&blk)
        @rake_tasks ||= []
        @rake_tasks << blk if blk
        @rake_tasks
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

    def rake_tasks
      self.class.rake_tasks
    end

    def generators
      self.class.generators
    end

    def load_tasks
      rake_tasks.each { |blk| blk.call }
    end

    def load_generators
      generators.each { |blk| blk.call }
    end
  end
end
