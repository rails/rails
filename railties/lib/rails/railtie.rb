module Rails
  class Railtie
    autoload :Configurable, "rails/railtie/configurable"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Plugin Rails::Engine Rails::Application)

    class << self
      def subclasses
        @subclasses ||= []
      end

      def inherited(base)
        unless abstract_railtie?(base)
          base.send(:include, self::Configurable) if add_configurable?(base)
          subclasses << base
        end
      end

      # TODO This should be called railtie_name and engine_name
      def plugin_name(plugin_name = nil)
        @plugin_name ||= name.demodulize.underscore
        @plugin_name = plugin_name if plugin_name
        @plugin_name
      end

      # TODO Deprecate me
      def plugins
        subclasses
      end

      # TODO Deprecate me
      def plugin_names
        plugins.map { |p| p.plugin_name }
      end

      def subscriber(subscriber)
        Rails::Subscriber.add(plugin_name, subscriber)
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

      # Just add configurable behavior if a Configurable module is defined
      # and the class is a direct child from self. This is required to avoid
      # application or plugins getting class configuration method from Railties
      # and/or Engines.
      def add_configurable?(base)
        defined?(self::Configurable) && base.ancestors[1] == self
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
