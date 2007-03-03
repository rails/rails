module Rails
  module Plugin
    class Locator
      include Enumerable
      attr_reader :initializer
      
      def initialize(initializer)
        @initializer = initializer
      end
      
      def plugins
        located_plugins.select(&:enabled?).sort
      end
      
      def each(&block)
        plugins.each(&block)
      end
      
      def plugin_names
        plugins.map(&:name)
      end
      
      private
        def located_plugins
          raise "The `located_plugins' method must be defined by concrete subclasses of #{self.class}"
        end
    end
    
    class FileSystemLocator < Locator
        private
          def located_plugins
            initializer.configuration.plugin_paths.flatten.inject([]) do |plugins, path|
              plugins.concat locate_plugins_under(path)
              plugins
            end.flatten
          end

          # This starts at the base path looking for directories that pass the plugin_path? test of the Plugin::Loader.
          # Since plugins can be nested arbitrarily deep within an unspecified number of intermediary directories, 
          # this method runs recursively until it finds a plugin directory.
          #
          #   e.g.
          #
          #     locate_plugins_under('vendor/plugins/acts/acts_as_chunky_bacon')
          #     => 'acts_as_chunky_bacon' 
          def locate_plugins_under(base_path)
             Dir.glob(File.join(base_path, '*')).inject([]) do |plugins, path|
              plugin_loader = initializer.configuration.plugin_loader.new(initializer, path)
              if plugin_loader.plugin_path? && plugin_loader.enabled?
                plugins << plugin_loader
              elsif File.directory?(path)
                plugins.concat locate_plugins_under(path)
              end
              plugins
            end
          end
    end
  end
end