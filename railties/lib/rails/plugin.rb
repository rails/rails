module Rails

  # The Plugin class should be an object which provides the following methods:
  #
  # * +name+       - used during initialisation to order the plugin (based on name and
  #                  the contents of <tt>config.plugins</tt>)
  # * +valid?+     - returns true if this plugin can be loaded
  # * +load_paths+ - each path within the returned array will be added to the $LOAD_PATH
  # * +load+       - finally 'load' the plugin.
  #
  # These methods are expected by the Rails::Plugin::Locator and Rails::Plugin::Loader classes.
  # The default implementation returns the <tt>lib</tt> directory as its </tt>load_paths</tt>, 
  # and evaluates <tt>init.rb</tt> when <tt>load</tt> is called.
  class Plugin
    include Comparable
    
    attr_reader :directory, :name
    
    def initialize(directory)
      @directory = directory
      @name = File.basename(@directory) rescue nil
      @loaded = false
    end
    
    def valid?
      File.directory?(directory) && (has_lib_directory? || has_init_file?)
    end
  
    # Returns a list of paths this plugin wishes to make available in $LOAD_PATH
    def load_paths
      report_nonexistant_or_empty_plugin! unless valid?
      has_lib_directory? ? [lib_path] : []
    end

    # Evaluates a plugin's init.rb file
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
    
    private

      def report_nonexistant_or_empty_plugin!
        raise LoadError, "Can not find the plugin named: #{name}"
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

      def evaluate_init_rb(initializer)
         if has_init_file?
           silence_warnings do
             # Allow plugins to reference the current configuration object
             config = initializer.configuration
             
             eval(IO.read(init_path), binding, init_path)
           end
         end
      end               
  end
end