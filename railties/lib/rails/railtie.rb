module Rails
  class Railtie
    include Initializable

    def self.plugin_name(plugin_name = nil)
      @plugin_name ||= name.demodulize.underscore
      @plugin_name = plugin_name if plugin_name
      @plugin_name
    end

    def self.inherited(klass)
      @plugins ||= []
      @plugins << klass unless klass == Plugin
    end

    def self.plugins
      @plugins
    end

    def self.plugin_names
      plugins.map { |p| p.plugin_name }
    end

    def self.config
      Configuration.default
    end

    def self.subscriber(subscriber)
      Rails::Subscriber.add(plugin_name, subscriber)
    end

    def self.rake_tasks(&blk)
      @rake_tasks ||= []
      @rake_tasks << blk if blk
      @rake_tasks
    end

    def rake_tasks
      self.class.rake_tasks
    end

    def load_tasks
      return unless rake_tasks
      rake_tasks.each { |blk| blk.call }
    end
  end
end
