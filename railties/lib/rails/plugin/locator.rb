module Rails
  class Plugin
    
    # The Plugin::Locator class should be subclasses to provide custom plugin-finding
    # abilities to Rails (i.e. loading plugins from Gems, etc). Each subclass should implement
    # the <tt>located_plugins</tt> method, which return an array of Plugin objects that have been found.
    class Locator
      include Enumerable
      
      attr_reader :initializer
      
      def initialize(initializer)
        @initializer = initializer
      end
      
      # This method should return all the plugins which this Plugin::Locator can find
      # These will then be used by the current Plugin::Loader, which is responsible for actually
      # loading the plugins themselves
      def plugins
        raise "The `plugins' method must be defined by concrete subclasses of #{self.class}"
      end
      
      def each(&block)
        plugins.each(&block)
      end
      
      def plugin_names
        plugins.map {|plugin| plugin.name }
      end
    end
    
    # The Rails::Plugin::FileSystemLocator will try to locate plugins by examining the directories
    # in the paths given in configuration.plugin_paths. Any plugins that can be found are returned
    # in a list. 
    #
    # The criteria for a valid plugin in this case is found in Rails::Plugin#valid?, although
    # other subclasses of Rails::Plugin::Locator can of course use different conditions.
    class FileSystemLocator < Locator
      
      # Returns all the plugins which can be loaded in the filesystem, under the paths given
      # by configuration.plugin_paths.
      def plugins
        initializer.configuration.plugin_paths.flatten.inject([]) do |plugins, path|
          plugins.concat locate_plugins_under(path)
          plugins
        end.flatten
      end
          
      private
      
        # Attempts to create a plugin from the given path. If the created plugin is valid?
        # (see Rails::Plugin#valid?) then the plugin instance is returned; otherwise nil.
        def create_plugin(path)
          plugin = Rails::Plugin.new(path)
          plugin.valid? ? plugin : nil
        end

        # This starts at the base path looking for valid plugins (see Rails::Plugin#valid?).
        # Since plugins can be nested arbitrarily deep within an unspecified number of intermediary 
        # directories, this method runs recursively until it finds a plugin directory, e.g.
        #
        #     locate_plugins_under('vendor/plugins/acts/acts_as_chunky_bacon')
        #     => <Rails::Plugin name: 'acts_as_chunky_bacon' ... >
        #
        def locate_plugins_under(base_path)
           Dir.glob(File.join(base_path, '*')).sort.inject([]) do |plugins, path|
            if plugin = create_plugin(path)
              plugins << plugin
            elsif File.directory?(path)
              plugins.concat locate_plugins_under(path)
            end
            plugins
          end
        end
    end

    # The GemLocator scans all the loaded RubyGems, looking for gems with
    # a <tt>rails/init.rb</tt> file.
    class GemLocator < Locator
      def plugins
        gem_index = initializer.configuration.gems.inject({}) { |memo, gem| memo.update gem.specification => gem }
        specs     = gem_index.keys
        specs    += Gem.loaded_specs.values.select do |spec|
          spec.loaded_from && # prune stubs
            File.exist?(File.join(spec.full_gem_path, "rails", "init.rb"))
        end
        specs.compact!

        require "rubygems/dependency_list"

        deps = Gem::DependencyList.new
        deps.add(*specs) unless specs.empty?

        deps.dependency_order.collect do |spec|
          Rails::GemPlugin.new(spec, gem_index[spec])
        end
      end
    end
  end
end