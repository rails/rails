module Rails
  class Engine < Railtie
    class Railties
      # TODO Write tests for this behavior extracted from Application
      def initialize(config)
        @config = config
      end

      def all(&block)
        @all ||= plugins
        @all.each(&block) if block
        @all
      end

      def plugins
        @plugins ||= begin
          plugin_names = (@config.plugins || [:all]).map { |p| p.to_sym }
          Plugin.all(plugin_names, @config.paths.vendor.plugins)
        end
      end
    end
  end
end
