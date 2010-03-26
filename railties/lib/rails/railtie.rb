require 'rails/initializable'
require 'rails/configuration'
require 'active_support/inflector'

module Rails
  class Railtie
    autoload :Configurable,  "rails/railtie/configurable"
    autoload :Configuration, "rails/railtie/configuration"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Railtie Rails::Plugin Rails::Engine Rails::Application)
    RAILTIES_TYPES    = ABSTRACT_RAILTIES.map { |r| r.split('::').last }

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

      def railtie_name(railtie_name = nil)
        @railtie_name = railtie_name if railtie_name
        @railtie_name ||= default_name
      end

      def railtie_names
        subclasses.map { |p| p.railtie_name }
      end

      def log_subscriber(log_subscriber)
        Rails::LogSubscriber.add(railtie_name, log_subscriber)
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

    protected

      def default_name
        namespaces = name.split("::")
        namespaces.pop if RAILTIES_TYPES.include?(namespaces.last)
        ActiveSupport::Inflector.underscore(namespaces.last).to_sym
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
