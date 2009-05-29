module Rails
  # The Plugin class should be an object which provides the following methods:
  #
  # * +name+       - Used during initialisation to order the plugin (based on name and
  #                  the contents of <tt>config.plugins</tt>).
  # * +valid?+     - Returns true if this plugin can be loaded.
  # * +load_paths+ - Each path within the returned array will be added to the <tt>$LOAD_PATH</tt>.
  # * +load+       - Finally 'load' the plugin.
  #
  # These methods are expected by the Rails::Plugin::Locator and Rails::Plugin::Loader classes.
  # The default implementation returns the <tt>lib</tt> directory as its <tt>load_paths</tt>, 
  # and evaluates <tt>init.rb</tt> when <tt>load</tt> is called.
  #
  # You can also inspect the about.yml data programmatically:
  #
  #   plugin = Rails::Plugin.new(path_to_my_plugin)
  #   plugin.about["author"] # => "James Adam"
  #   plugin.about["url"] # => "http://interblah.net"
  class Plugin
    include Comparable
    
    attr_reader :directory, :name
    
    def initialize(directory)
      @directory = directory
      @name      = File.basename(@directory) rescue nil
      @loaded    = false
    end
    
    def valid?
      File.directory?(directory) && (has_app_directory? || has_lib_directory? || has_init_file?)
    end
  
    # Returns a list of paths this plugin wishes to make available in <tt>$LOAD_PATH</tt>.
    def load_paths
      report_nonexistant_or_empty_plugin! unless valid?
      
      load_paths = []
      load_paths << lib_path  if has_lib_directory?
      load_paths << app_paths if has_app_directory?
      load_paths.flatten
    end
    
    # Evaluates a plugin's init.rb file.
    def load(initializer)
      return if loaded?
      report_nonexistant_or_empty_plugin! unless valid?
      evaluate_init_rb(initializer)
      @loaded = true
    end
    
    def loaded?
      @loaded
    end
    
    def <=>(other_plugin)
      name <=> other_plugin.name
    end

    def about
      @about ||= load_about_information
    end

    # Engines are plugins with an app/ directory.
    def engine?
      has_app_directory?
    end
    
    # Returns true if the engine ships with a routing file
    def routed?
      File.exist?(routing_file)
    end


    def view_path
      File.join(directory, 'app', 'views')
    end

    def controller_path
      File.join(directory, 'app', 'controllers')
    end

    def metal_path
      File.join(directory, 'app', 'metal')
    end

    def routing_file
      File.join(directory, 'config', 'routes.rb')
    end
    

    private
      def load_about_information
        about_yml_path = File.join(@directory, "about.yml")
        parsed_yml = File.exist?(about_yml_path) ? YAML.load(File.read(about_yml_path)) : {}
        parsed_yml || {}
      rescue Exception
        {}
      end

      def report_nonexistant_or_empty_plugin!
        raise LoadError, "Can not find the plugin named: #{name}"
      end

      
      def app_paths
        [ File.join(directory, 'app', 'models'), File.join(directory, 'app', 'helpers'), controller_path, metal_path ]
      end
      
      def lib_path
        File.join(directory, 'lib')
      end

      def classic_init_path
        File.join(directory, 'init.rb')
      end

      def gem_init_path
        File.join(directory, 'rails', 'init.rb')
      end

      def init_path
        File.file?(gem_init_path) ? gem_init_path : classic_init_path
      end


      def has_app_directory?
        File.directory?(File.join(directory, 'app'))
      end

      def has_lib_directory?
        File.directory?(lib_path)
      end

      def has_init_file?
        File.file?(init_path)
      end


      def evaluate_init_rb(initializer)
        if has_init_file?
          require 'active_support/core_ext/kernel/reporting'
          silence_warnings do
            # Allow plugins to reference the current configuration object
            config = initializer.configuration
            
            eval(IO.read(init_path), binding, init_path)
          end
        end
      end               
  end

  # This Plugin subclass represents a Gem plugin. Although RubyGems has already
  # taken care of $LOAD_PATHs, it exposes its load_paths to add them
  # to Dependencies.load_paths.
  class GemPlugin < Plugin
    # Initialize this plugin from a Gem::Specification.
    def initialize(spec, gem)
      directory = spec.full_gem_path
      super(directory)
      @name = spec.name
    end

    def init_path
      File.join(directory, 'rails', 'init.rb')
    end
  end
end
