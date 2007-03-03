module Rails
  module Plugin
    class Loader
      include Comparable
      attr_reader :initializer, :directory, :name
  
      class << self
        def load(*args)
          new(*args).load
        end
      end
  
      def initialize(initializer, directory)
        @initializer = initializer
        @directory   = directory
        @name        = File.basename(directory)
      end
  
      def load
        return false if loaded?
        report_nonexistant_or_empty_plugin!
        add_to_load_path!
        register_plugin_as_loaded
        evaluate
        true
      end
  
      def loaded?
        initializer.loaded_plugins.include?(name)
      end
  
      def plugin_path?
        File.directory?(directory) && (has_lib_directory? || has_init_file?)
      end
      
      def enabled?
        !explicit_plugin_loading_order? || registered?
      end
        
      def registered?
        explicit_plugin_loading_order? && registered_plugins.include?(name)
      end
      
      def plugin_does_not_exist!(plugin_name = name)
        raise LoadError, "Can not find the plugin named: #{plugin_name}"
      end
      
      private
        # The plugins that have been explicitly listed with config.plugins. If this list is nil
        # then it means the client does not care which plugins or in what order they are loaded, 
        # so we load all in alphabetical order. If it is an empty array, we load no plugins, if it is
        # non empty, we load the named plugins in the order specified.
        def registered_plugins
          config.plugins
        end
        
        def explicit_plugin_loading_order?
          !registered_plugins.nil?
        end
        
        def report_nonexistant_or_empty_plugin!
          plugin_does_not_exist! unless plugin_path?
        end
        
        def lib_path
          File.join(directory, 'lib')
        end
  
        def init_path
          File.join(directory, 'init.rb')
        end
  
        def has_lib_directory?
          File.directory?(lib_path)
        end
  
        def has_init_file?
          File.file?(init_path)
        end
  
        def add_to_load_path!
          # Add lib to load path *after* the application lib, to allow
          # application libraries to override plugin libraries.
          if has_lib_directory?
            application_lib_index = $LOAD_PATH.index(application_library_path) || 0
            $LOAD_PATH.insert(application_lib_index + 1, lib_path)
            Dependencies.load_paths      << lib_path
            Dependencies.load_once_paths << lib_path
          end
        end
      
        def application_library_path
          File.join(RAILS_ROOT, 'lib')
        end
  
        # Allow plugins to reference the current configuration object
        def config
          initializer.configuration
        end
  
        def register_plugin_as_loaded
          initializer.loaded_plugins << name
        end
  
        # Evaluate in init.rb
        def evaluate
          silence_warnings { eval(IO.read(init_path), binding, init_path)} if has_init_file?
        end
      
        def <=>(other_plugin_loader)
          if explicit_plugin_loading_order?
            if non_existent_plugin = [self, other_plugin_loader].detect {|plugin| !registered_plugins.include?(plugin.name)}
              plugin_does_not_exist!(non_existent_plugin.name)
            end
            
            registered_plugins.index(name) <=> registered_plugins.index(other_plugin_loader.name)
          else
            name <=> other_plugin_loader.name
          end
        end
    end
  end
end
