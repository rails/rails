require 'rails/initializable'
require 'rails/configuration'

module Rails
  class Railtie
    autoload :Configurable,  "rails/railtie/configurable"
    autoload :Configuration, "rails/railtie/configuration"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Plugin Rails::Engine Rails::Application)

    class << self
      def subclasses
        @subclasses ||= []
      end

      def inherited(base)
        unless abstract_railtie?(base)
          base.send(:include, self::Configurable)
          subclasses << base
        end
      end

      def railtie_name(railtie_name = nil)
        @railtie_name ||= name.demodulize.underscore
        @railtie_name = railtie_name if railtie_name
        @railtie_name
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

    protected

      def abstract_railtie?(base)
        ABSTRACT_RAILTIES.include?(base.name)
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
