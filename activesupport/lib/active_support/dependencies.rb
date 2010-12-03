require 'set'
require 'thread'
require 'pathname'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/name_error'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/inflector'

module ActiveSupport #:nodoc:
  module Dependencies #:nodoc:
    extend self

    # Should we turn on Ruby warnings on the first load of dependent files?
    mattr_accessor :warnings_on_first_load
    self.warnings_on_first_load = false

    # All files ever loaded.
    mattr_accessor :history
    self.history = Set.new

    # All files currently loaded.
    mattr_accessor :loaded
    self.loaded = Set.new

    # Should we load files or require them?
    mattr_accessor :mechanism
    self.mechanism = ENV['NO_RELOAD'] ? :require : :load

    # The set of directories from which we may automatically load files. Files
    # under these directories will be reloaded on each request in development mode,
    # unless the directory also appears in autoload_once_paths.
    mattr_accessor :autoload_paths
    self.autoload_paths = []

    # The set of directories from which automatically loaded constants are loaded
    # only once. All directories in this set must also be present in +autoload_paths+.
    mattr_accessor :autoload_once_paths
    self.autoload_once_paths = []

    # An array of qualified constant names that have been loaded. Adding a name to
    # this array will cause it to be unloaded the next time Dependencies are cleared.
    mattr_accessor :autoloaded_constants
    self.autoloaded_constants = []

    mattr_accessor :references
    self.references = {}

    # An array of constant names that need to be unloaded on every request. Used
    # to allow arbitrary constants to be marked for unloading.
    mattr_accessor :explicitly_unloadable_constants
    self.explicitly_unloadable_constants = []

    # The logger is used for generating information on the action run-time (including benchmarking) if available.
    # Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
    mattr_accessor :logger

    # Set to true to enable logging of const_missing and file loads
    mattr_accessor :log_activity
    self.log_activity = false

    # The WatchStack keeps a stack of the modules being watched as files are loaded.
    # If a file in the process of being loaded (parent.rb) triggers the load of 
    # another file (child.rb) the stack will ensure that child.rb handles the new 
    # constants.
    #
    # If child.rb is being autoloaded, its constants will be added to
    # autoloaded_constants. If it was being `require`d, they will be discarded.
    #
    # This is handled by walking back up the watch stack and adding the constants
    # found by child.rb to the list of original constants in parent.rb
    class WatchStack < Hash
      # @watching is a stack of lists of constants being watched. For instance,
      # if parent.rb is autoloaded, the stack will look like [[Object]]. If parent.rb
      # then requires namespace/child.rb, the stack will look like [[Object], [Namespace]].

      def initialize
        @watching = []
        super { |h,k| h[k] = [] }
      end

      # return a list of new constants found since the last call to watch_modules
      def new_constants
        constants = []

        # Grab the list of namespaces that we're looking for new constants under
        @watching.last.each do |namespace|
          # Retrieve the constants that were present under the namespace when watch_modules
          # was originally called
          original_constants = self[namespace].last

          mod = Inflector.constantize(namespace) if Dependencies.qualified_const_defined?(namespace)
          next unless mod.is_a?(Module)

          # Get a list of the constants that were added
          new_constants = mod.local_constant_names - original_constants

          # self[namespace] returns an Array of the constants that are being evaluated
          # for that namespace. For instance, if parent.rb requires child.rb, the first
          # element of self[Object] will be an Array of the constants that were present
          # before parent.rb was required. The second element will be an Array of the
          # constants that were present before child.rb was required.
          self[namespace].each do |namespace_constants|
            namespace_constants.concat(new_constants)
          end

          # Normalize the list of new constants, and add them to the list we will return
          new_constants.each do |suffix|
            constants << ([namespace, suffix] - ["Object"]).join("::")
          end
        end
        constants
      ensure
        # A call to new_constants is always called after a call to watch_modules
        pop_modules(@watching.pop)
      end

      # Add a set of modules to the watch stack, remembering the initial constants
      def watch_namespaces(namespaces)
        watching = []
        namespaces.map do |namespace|
          module_name = Dependencies.to_constant_name(namespace)
          original_constants = Dependencies.qualified_const_defined?(module_name) ?
            Inflector.constantize(module_name).local_constant_names : []

          watching << module_name
          self[module_name] << original_constants
        end
        @watching << watching
      end

      def pop_modules(modules)
        modules.each { |mod| self[mod].pop }
      end
    end

    # An internal stack used to record which constants are loaded by any block.
    mattr_accessor :constant_watch_stack
    self.constant_watch_stack = WatchStack.new

    # Module includes this module
    module ModuleConstMissing #:nodoc:
      def self.append_features(base)
        base.class_eval do
          # Emulate #exclude via an ivar
          return if defined?(@_const_missing) && @_const_missing
          @_const_missing = instance_method(:const_missing)
          remove_method(:const_missing)
        end
        super
      end

      def self.exclude_from(base)
        base.class_eval do
          define_method :const_missing, @_const_missing
          @_const_missing = nil
        end
      end

      # Use const_missing to autoload associations so we don't have to
      # require_association when using single-table inheritance.
      def const_missing(const_name, nesting = nil)
        klass_name = name.presence || "Object"

        if !nesting
          # We'll assume that the nesting of Foo::Bar is ["Foo::Bar", "Foo"]
          # even though it might not be, such as in the case of
          # class Foo::Bar; Baz; end
          nesting = []
          klass_name.to_s.scan(/::|$/) { nesting.unshift $` }
        end

        # If there are multiple levels of nesting to search under, the top
        # level is the one we want to report as the lookup fail.
        error = nil

        nesting.each do |namespace|
          begin
            return Dependencies.load_missing_constant Inflector.constantize(namespace), const_name
          rescue NoMethodError then raise
          rescue NameError => e
            error ||= e
          end
        end

        # Raise the first error for this set. If this const_missing came from an
        # earlier const_missing, this will result in the real error bubbling
        # all the way up
        raise error
      end

      def unloadable(const_desc = self)
        super(const_desc)
      end
    end

    # Object includes this module
    module Loadable #:nodoc:
      def self.exclude_from(base)
        base.class_eval { define_method(:load, Kernel.instance_method(:load)) }
      end

      def require_or_load(file_name)
        Dependencies.require_or_load(file_name)
      end

      def require_dependency(file_name, message = "No such file to load -- %s")
        unless file_name.is_a?(String)
          raise ArgumentError, "the file name must be a String -- you passed #{file_name.inspect}"
        end

        Dependencies.depend_on(file_name, false, message)
      end

      def require_association(file_name)
        Dependencies.associate_with(file_name)
      end

      def load_dependency(file)
        if Dependencies.load?
          Dependencies.new_constants_in(Object) { yield }.presence
        else
          yield
        end
      rescue Exception => exception  # errors from loading file
        exception.blame_file! file
        raise
      end

      def load(file, *)
        load_dependency(file) { super }
      end

      def require(file, *)
        load_dependency(file) { super }
      end

      # Mark the given constant as unloadable. Unloadable constants are removed each
      # time dependencies are cleared.
      #
      # Note that marking a constant for unloading need only be done once. Setup
      # or init scripts may list each unloadable constant that may need unloading;
      # each constant will be removed for every subsequent clear, as opposed to for
      # the first clear.
      #
      # The provided constant descriptor may be a (non-anonymous) module or class,
      # or a qualified constant name as a string or symbol.
      #
      # Returns true if the constant was not previously marked for unloading, false
      # otherwise.
      def unloadable(const_desc)
        Dependencies.mark_for_unload const_desc
      end
    end

    # Exception file-blaming
    module Blamable #:nodoc:
      def blame_file!(file)
        (@blamed_files ||= []).unshift file
      end

      def blamed_files
        @blamed_files ||= []
      end

      def describe_blame
        return nil if blamed_files.empty?
        "This error occurred while loading the following files:\n   #{blamed_files.join "\n   "}"
      end

      def copy_blame!(exc)
        @blamed_files = exc.blamed_files.clone
        self
      end
    end

    def hook!
      Object.class_eval { include Loadable }
      Module.class_eval { include ModuleConstMissing }
      Exception.class_eval { include Blamable }
      true
    end

    def unhook!
      ModuleConstMissing.exclude_from(Module)
      Loadable.exclude_from(Object)
      true
    end

    def load?
      mechanism == :load
    end

    def depend_on(file_name, swallow_load_errors = false, message = "No such file to load -- %s.rb")
      path = search_for_file(file_name)
      require_or_load(path || file_name)
    rescue LoadError => load_error
      unless swallow_load_errors
        if file_name = load_error.message[/ -- (.*?)(\.rb)?$/, 1]
          raise LoadError.new(message % file_name).copy_blame!(load_error)
        end
        raise
      end
    end

    def associate_with(file_name)
      depend_on(file_name, true)
    end

    def clear
      log_call
      loaded.clear
      remove_unloadable_constants!
    end

    def require_or_load(file_name, const_path = nil)
      log_call file_name, const_path
      file_name = $1 if file_name =~ /^(.*)\.rb$/
      expanded = File.expand_path(file_name)
      return if loaded.include?(expanded)

      # Record that we've seen this file *before* loading it to avoid an
      # infinite loop with mutual dependencies.
      loaded << expanded

      begin
        if load?
          log "loading #{file_name}"

          # Enable warnings if this file has not been loaded before and
          # warnings_on_first_load is set.
          load_args = ["#{file_name}.rb"]
          load_args << const_path unless const_path.nil?

          if !warnings_on_first_load or history.include?(expanded)
            result = load_file(*load_args)
          else
            enable_warnings { result = load_file(*load_args) }
          end
        else
          log "requiring #{file_name}"
          result = require file_name
        end
      rescue Exception
        loaded.delete expanded
        raise
      end

      # Record history *after* loading so first load gets warnings.
      history << expanded
      return result
    end

    # Is the provided constant path defined?
    def qualified_const_defined?(path)
      names = path.sub(/^::/, '').to_s.split('::')

      names.inject(Object) do |mod, name|
        return false unless local_const_defined?(mod, name)
        mod.const_get name
      end
    end

    if Module.method(:const_defined?).arity == 1
      # Does this module define this constant?
      # Wrapper to accommodate changing Module#const_defined? in Ruby 1.9
      def local_const_defined?(mod, const)
        mod.const_defined?(const)
      end
    else
      def local_const_defined?(mod, const) #:nodoc:
        mod.const_defined?(const, false)
      end
    end

    # Given +path+, a filesystem path to a ruby file, return an array of constant
    # paths which would cause Dependencies to attempt to load this file.
    def loadable_constants_for_path(path, bases = autoload_paths)
      path = $1 if path =~ /\A(.*)\.rb\Z/
      expanded_path = File.expand_path(path)
      paths = []

      bases.each do |root|
        expanded_root = File.expand_path(root)
        next unless %r{\A#{Regexp.escape(expanded_root)}(/|\\)} =~ expanded_path

        nesting = expanded_path[(expanded_root.size)..-1]
        nesting = nesting[1..-1] if nesting && nesting[0] == ?/
        next if nesting.blank?

        paths << nesting.camelize
      end

      paths.uniq!
      paths
    end

    # Search for a file in autoload_paths matching the provided suffix.
    def search_for_file(path_suffix)
      path_suffix = path_suffix.sub(/(\.rb)?$/, ".rb")

      autoload_paths.each do |root|
        path = File.join(root, path_suffix)
        return path if File.file? path
      end
      nil # Gee, I sure wish we had first_match ;-)
    end

    # Does the provided path_suffix correspond to an autoloadable module?
    # Instead of returning a boolean, the autoload base for this module is returned.
    def autoloadable_module?(path_suffix)
      autoload_paths.each do |load_path|
        return load_path if File.directory? File.join(load_path, path_suffix)
      end
      nil
    end

    def load_once_path?(path)
      autoload_once_paths.any? { |base| path.starts_with? base }
    end

    # Attempt to autoload the provided module name by searching for a directory
    # matching the expect path suffix. If found, the module is created and assigned
    # to +into+'s constants with the name +const_name+. Provided that the directory
    # was loaded from a reloadable base path, it is added to the set of constants
    # that are to be unloaded.
    def autoload_module!(into, const_name, qualified_name, path_suffix)
      return nil unless base_path = autoloadable_module?(path_suffix)
      mod = Module.new
      into.const_set const_name, mod
      autoloaded_constants << qualified_name unless autoload_once_paths.include?(base_path)
      return mod
    end

    # Load the file at the provided path. +const_paths+ is a set of qualified
    # constant names. When loading the file, Dependencies will watch for the
    # addition of these constants. Each that is defined will be marked as
    # autoloaded, and will be removed when Dependencies.clear is next called.
    #
    # If the second parameter is left off, then Dependencies will construct a set
    # of names that the file at +path+ may define. See
    # +loadable_constants_for_path+ for more details.
    def load_file(path, const_paths = loadable_constants_for_path(path))
      log_call path, const_paths
      const_paths = [const_paths].compact unless const_paths.is_a? Array
      parent_paths = const_paths.collect { |const_path| /(.*)::[^:]+\Z/ =~ const_path ? $1 : :Object }

      result = nil
      newly_defined_paths = new_constants_in(*parent_paths) do
        result = Kernel.load path
      end

      autoloaded_constants.concat newly_defined_paths unless load_once_path?(path)
      autoloaded_constants.uniq!
      log "loading #{path} defined #{newly_defined_paths * ', '}" unless newly_defined_paths.empty?
      return result
    end

    # Return the constant path for the provided parent and constant name.
    def qualified_name_for(mod, name)
      mod_name = to_constant_name mod
      mod_name == "Object" ? name.to_s : "#{mod_name}::#{name}"
    end

    # Load the constant named +const_name+ which is missing from +from_mod+. If
    # it is not possible to load the constant into from_mod, try its parent module
    # using const_missing.
    def load_missing_constant(from_mod, const_name)
      log_call from_mod, const_name

      unless qualified_const_defined?(from_mod.name) && Inflector.constantize(from_mod.name).equal?(from_mod)
        raise ArgumentError, "A copy of #{from_mod} has been removed from the module tree but is still active!"
      end

      raise ArgumentError, "#{from_mod} is not missing constant #{const_name}!" if local_const_defined?(from_mod, const_name)

      qualified_name = qualified_name_for from_mod, const_name
      path_suffix = qualified_name.underscore

      trace = caller.reject {|l| l =~ %r{#{Regexp.escape(__FILE__)}}}
      name_error = NameError.new("uninitialized constant #{qualified_name}")
      name_error.set_backtrace(trace)

      file_path = search_for_file(path_suffix)

      if file_path && ! loaded.include?(File.expand_path(file_path)) # We found a matching file to load
        require_or_load file_path
        raise LoadError, "Expected #{file_path} to define #{qualified_name}" unless local_const_defined?(from_mod, const_name)
        return from_mod.const_get(const_name)
      elsif mod = autoload_module!(from_mod, const_name, qualified_name, path_suffix)
        return mod
      elsif (parent = from_mod.parent) && parent != from_mod &&
            ! from_mod.parents.any? { |p| local_const_defined?(p, const_name) }
        # If our parents do not have a constant named +const_name+ then we are free
        # to attempt to load upwards. If they do have such a constant, then this
        # const_missing must be due to from_mod::const_name, which should not
        # return constants from from_mod's parents.
        begin
          return parent.const_missing(const_name)
        rescue NameError => e
          raise unless e.missing_name? qualified_name_for(parent, const_name)
          raise name_error
        end
      else
        raise name_error
      end
    end

    # Remove the constants that have been autoloaded, and those that have been
    # marked for unloading. Before each constant is removed a callback is sent
    # to its class/module if it implements +before_remove_const+.
    #
    # The callback implementation should be restricted to cleaning up caches, etc.
    # as the enviroment will be in an inconsistent state, e.g. other constants
    # may have already been unloaded and not accessible.
    def remove_unloadable_constants!
      autoloaded_constants.each { |const| remove_constant const }
      autoloaded_constants.clear
      Reference.clear!
      explicitly_unloadable_constants.each { |const| remove_constant const }
    end

    class Reference
      @@constants = Hash.new { |h, k| h[k] = Inflector.constantize(k) }

      attr_reader :name

      def initialize(name)
        @name = name.to_s
        @@constants[@name] = name if name.respond_to?(:name)
      end

      def get
        @@constants[@name]
      end

      def self.clear!
        @@constants.clear
      end
    end

    def ref(name)
      references[name] ||= Reference.new(name)
    end

    def constantize(name)
      ref(name).get
    end

    # Determine if the given constant has been automatically loaded.
    def autoloaded?(desc)
      # No name => anonymous module.
      return false if desc.is_a?(Module) && desc.anonymous?
      name = to_constant_name desc
      return false unless qualified_const_defined? name
      return autoloaded_constants.include?(name)
    end

    # Will the provided constant descriptor be unloaded?
    def will_unload?(const_desc)
      autoloaded?(const_desc) ||
        explicitly_unloadable_constants.include?(to_constant_name(const_desc))
    end

    # Mark the provided constant name for unloading. This constant will be
    # unloaded on each request, not just the next one.
    def mark_for_unload(const_desc)
      name = to_constant_name const_desc
      if explicitly_unloadable_constants.include? name
        return false
      else
        explicitly_unloadable_constants << name
        return true
      end
    end

    # Run the provided block and detect the new constants that were loaded during
    # its execution. Constants may only be regarded as 'new' once -- so if the
    # block calls +new_constants_in+ again, then the constants defined within the
    # inner call will not be reported in this one.
    #
    # If the provided block does not run to completion, and instead raises an
    # exception, any new constants are regarded as being only partially defined
    # and will be removed immediately.
    def new_constants_in(*descs)
      log_call(*descs)

      constant_watch_stack.watch_namespaces(descs)
      aborting = true

      begin
        yield # Now yield to the code that is to define new constants.
        aborting = false
      ensure
        new_constants = constant_watch_stack.new_constants

        log "New constants: #{new_constants * ', '}"
        return new_constants unless aborting

        log "Error during loading, removing partially loaded constants "
        new_constants.each {|c| remove_constant(c) }.clear
      end

      return []
    end

    class LoadingModule #:nodoc:
      # Old style environment.rb referenced this method directly.  Please note, it doesn't
      # actually *do* anything any more.
      def self.root(*args)
        if defined?(Rails) && Rails.logger
          Rails.logger.warn "Your environment.rb uses the old syntax, it may not continue to work in future releases."
          Rails.logger.warn "For upgrade instructions please see: http://manuals.rubyonrails.com/read/book/19"
        end
      end
    end

    # Convert the provided const desc to a qualified constant name (as a string).
    # A module, class, symbol, or string may be provided.
    def to_constant_name(desc) #:nodoc:
      case desc
        when String then desc.sub(/^::/, '')
        when Symbol then desc.to_s
        when Module
          desc.name.presence ||
            raise(ArgumentError, "Anonymous modules have no name to be referenced by")
        else raise TypeError, "Not a valid constant descriptor: #{desc.inspect}"
      end
    end

    def remove_constant(const) #:nodoc:
      return false unless qualified_const_defined? const

      # Normalize ::Foo, Foo, Object::Foo, and ::Object::Foo to Object::Foo
      names = const.to_s.sub(/^::(Object)?/, 'Object::').split("::")
      to_remove = names.pop
      parent = Inflector.constantize(names * '::')

      log "removing constant #{const}"
      constantize(const).before_remove_const if constantize(const).respond_to?(:before_remove_const)
      parent.instance_eval { remove_const to_remove }

      return true
    end

    protected
      def log_call(*args)
        if logger && log_activity
          arg_str = args.collect { |arg| arg.inspect } * ', '
          /in `([a-z_\?\!]+)'/ =~ caller(1).first
          selector = $1 || '<unknown>'
          log "called #{selector}(#{arg_str})"
        end
      end

      def log(msg)
        if logger && log_activity
          logger.debug "Dependencies: #{msg}"
        end
      end
  end
end

ActiveSupport::Dependencies.hook!
