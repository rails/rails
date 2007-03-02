module Rails
  module Plugin
    class Locater
      include Enumerable
      attr_reader :initializer
      
      def initialize(initializer)
        @initializer = initializer
      end
      
      def plugins
        if !explicit_plugin_loading_order?
          # We don't care about which plugins get loaded or in what order they are loaded
          # so we load 'em all in a reliable order
          located_plugins.sort
        elsif !registered_plugins.empty?
          registered_plugins.inject([]) do |plugins, registered_plugin|
            report_plugin_missing!(registered_plugin) unless plugin = locate_registered_plugin(registered_plugin)
            plugins << plugin
          end
        else
          []
        end
      end
      
      def each(&block)
        plugins.each(&block)
      end
      
      def plugin_names
        plugins.map {|plugin| plugin.name}
      end
      
      private
        def locate_registered_plugin(registered_plugin)
          located_plugins.detect {|plugin| plugin.name == registered_plugin }
        end
        
        def report_plugin_missing!(name)
          raise LoadError, "Cannot find the plugin you registered called '#{name}'!"
        end
        
        def explicit_plugin_loading_order?
          !registered_plugins.nil?
        end
        
        # The plugins that have been explicitly listed with config.plugins. If this list is nil
        # then it means the client does not care which plugins or in what order they are loaded, 
        # so we load all in alphabetical order. If it is an empty array, we load no plugins, if it is
        # non empty, we load the named plugins in the order specified.
        def registered_plugins
          initializer.configuration.plugins
        end
      
        def located_plugins
          # We cache this as locate_plugins_under on the entire set of plugin directories could 
          # be potentially expensive
          @located_plugins ||=
            begin
              initializer.configuration.plugin_paths.flatten.inject([]) do |plugins, path|
                plugins.concat locate_plugins_under(path)
                plugins
              end.flatten
            end         
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
            if plugin_loader.plugin_path?
              plugins << plugin_loader if plugin_loader.enabled?
            elsif File.directory?(path)
              plugins.concat locate_plugins_under(path)
            end
            plugins
          end
        end
    end
  end
end