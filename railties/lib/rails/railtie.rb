module Rails
  class Railtie
    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Plugin Rails::Engine Rails::Application)

    class << self
      def abstract_railtie?(base)
        ABSTRACT_RAILTIES.include?(base.name)
      end

      def inherited(base)
        @@plugins ||= []
        @@plugins << base unless abstract_railtie?(base)
      end

      # This should be called railtie_name and engine_name
      def plugin_name(plugin_name = nil)
        @plugin_name ||= name.demodulize.underscore
        @plugin_name = plugin_name if plugin_name
        @plugin_name
      end

      def plugins
        @@plugins
      end

      def plugin_names
        plugins.map { |p| p.plugin_name }
      end

      def config
        Configuration.default
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
    end

    def rake_tasks
      self.class.rake_tasks
    end

    def generators
      self.class.generators
    end

    def load_tasks
      return unless rake_tasks
      rake_tasks.each { |blk| blk.call }
    end

    def load_generators
      return unless generators
      generators.each { |blk| blk.call }
    end
  end
end
