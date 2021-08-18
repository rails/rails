# frozen_string_literal: true

require "set"
require "thread"
require "concurrent/map"
require "pathname"
require "active_support/core_ext/module/aliasing"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/module/introspection"
require "active_support/core_ext/module/anonymous"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/load_error"
require "active_support/core_ext/name_error"
require "active_support/dependencies/interlock"
require "active_support/inflector"

module ActiveSupport # :nodoc:
  module Dependencies # :nodoc:
    require_relative "dependencies/require_dependency"

    extend self

    UNBOUND_METHOD_MODULE_NAME = Module.instance_method(:name)
    private_constant :UNBOUND_METHOD_MODULE_NAME

    mattr_accessor :interlock, default: Interlock.new

    # :doc:

    # Execute the supplied block without interference from any
    # concurrent loads.
    def self.run_interlock
      Dependencies.interlock.running { yield }
    end

    # Execute the supplied block while holding an exclusive lock,
    # preventing any other thread from being inside a #run_interlock
    # block at the same time.
    def self.load_interlock
      Dependencies.interlock.loading { yield }
    end

    # Execute the supplied block while holding an exclusive lock,
    # preventing any other thread from being inside a #run_interlock
    # block at the same time.
    def self.unload_interlock
      Dependencies.interlock.unloading { yield }
    end

    # :nodoc:

    def eager_load?(path)
      Dependencies._eager_load_paths.member?(path)
    end

    # All files ever loaded.
    mattr_accessor :history, default: Set.new

    # All files currently loaded.
    mattr_accessor :loaded, default: Set.new

    # Stack of files being loaded.
    mattr_accessor :loading, default: []

    # Should we load files or require them?
    mattr_accessor :mechanism, default: ENV["NO_RELOAD"] ? :require : :load

    # The set of directories from which we may automatically load files. Files
    # under these directories will be reloaded on each request in development mode,
    # unless the directory also appears in autoload_once_paths.
    mattr_accessor :autoload_paths, default: []

    # The set of directories from which automatically loaded constants are loaded
    # only once. All directories in this set must also be present in +autoload_paths+.
    mattr_accessor :autoload_once_paths, default: []

    # This is a private set that collects all eager load paths during bootstrap.
    # Useful for Zeitwerk integration. Its public interface is the config.* path
    # accessors of each engine.
    mattr_accessor :_eager_load_paths, default: Set.new

    # An array of qualified constant names that have been loaded. Adding a name
    # to this array will cause it to be unloaded the next time Dependencies are
    # cleared.
    mattr_accessor :autoloaded_constants, default: []

    # An array of constant names that need to be unloaded on every request. Used
    # to allow arbitrary constants to be marked for unloading.
    mattr_accessor :explicitly_unloadable_constants, default: []

    # The WatchStack keeps a stack of the modules being watched as files are
    # loaded. If a file in the process of being loaded (parent.rb) triggers the
    # load of another file (child.rb) the stack will ensure that child.rb
    # handles the new constants.
    #
    # If child.rb is being autoloaded, its constants will be added to
    # autoloaded_constants. If it was being required, they will be discarded.
    #
    # This is handled by walking back up the watch stack and adding the constants
    # found by child.rb to the list of original constants in parent.rb.
    class WatchStack
      include Enumerable

      # @watching is a stack of lists of constants being watched. For instance,
      # if parent.rb is autoloaded, the stack will look like [[Object]]. If
      # parent.rb then requires namespace/child.rb, the stack will look like
      # [[Object], [Namespace]].

      attr_reader :watching

      def initialize
        @watching = []
        @stack = Hash.new { |h, k| h[k] = [] }
      end

      def each(&block)
        @stack.each(&block)
      end

      def watching?
        !@watching.empty?
      end

      # Returns a list of new constants found since the last call to
      # <tt>watch_namespaces</tt>.
      def new_constants
        constants = []

        # Grab the list of namespaces that we're looking for new constants under
        @watching.last.each do |namespace|
          # Retrieve the constants that were present under the namespace when watch_namespaces
          # was originally called
          original_constants = @stack[namespace].last

          mod = Inflector.constantize(namespace) if Dependencies.qualified_const_defined?(namespace)
          next unless mod.is_a?(Module)

          # Get a list of the constants that were added
          new_constants = mod.constants(false) - original_constants

          # @stack[namespace] returns an Array of the constants that are being evaluated
          # for that namespace. For instance, if parent.rb requires child.rb, the first
          # element of @stack[Object] will be an Array of the constants that were present
          # before parent.rb was required. The second element will be an Array of the
          # constants that were present before child.rb was required.
          @stack[namespace].each do |namespace_constants|
            namespace_constants.concat(new_constants)
          end

          # Normalize the list of new constants, and add them to the list we will return
          new_constants.each do |suffix|
            constants << ([namespace, suffix] - ["Object"]).join("::")
          end
        end
        constants
      ensure
        # A call to new_constants is always called after a call to watch_namespaces
        pop_modules(@watching.pop)
      end

      # Add a set of modules to the watch stack, remembering the initial
      # constants.
      def watch_namespaces(namespaces)
        @watching << namespaces.map do |namespace|
          module_name = Dependencies.to_constant_name(namespace)
          original_constants = Dependencies.qualified_const_defined?(module_name) ?
            Inflector.constantize(module_name).constants(false) : []

          @stack[module_name] << original_constants
          module_name
        end
      end

      private
        def pop_modules(modules)
          modules.each { |mod| @stack[mod].pop }
        end
    end

    # An internal stack used to record which constants are loaded by any block.
    mattr_accessor :constant_watch_stack, default: WatchStack.new

    def load?
      mechanism == :load
    end

    def clear
      Dependencies.unload_interlock do
        loaded.clear
        loading.clear
      end
    end

    # Is the provided constant path defined?
    def qualified_const_defined?(path)
      Object.const_defined?(path, false)
    end

    # Search for a file in autoload_paths matching the provided suffix.
    def search_for_file(path_suffix)
      path_suffix += ".rb" unless path_suffix.end_with?(".rb")

      autoload_paths.each do |root|
        path = File.join(root, path_suffix)
        return path if File.file? path
      end
      nil # Gee, I sure wish we had first_match ;-)
    end

    # Does the provided path_suffix correspond to an autoloadable module?
    # Instead of returning a boolean, the autoload base for this module is
    # returned.
    def autoloadable_module?(path_suffix)
      autoload_paths.each do |load_path|
        return load_path if File.directory? File.join(load_path, path_suffix)
      end
      nil
    end

    def load_once_path?(path)
      # to_s works around a ruby issue where String#start_with?(Pathname)
      # will raise a TypeError: no implicit conversion of Pathname into String
      autoload_once_paths.any? { |base| path.start_with?(base.to_s) }
    end

    # Returns the constant path for the provided parent and constant name.
    def qualified_name_for(mod, name)
      mod_name = to_constant_name mod
      mod_name == "Object" ? name.to_s : "#{mod_name}::#{name}"
    end

    # Get the reference for class named +name+.
    # Raises an exception if referenced class does not exist.
    def constantize(name)
      Inflector.constantize(name)
    end

    # Get the reference for class named +name+ if one exists.
    # Otherwise returns +nil+.
    def safe_constantize(name)
      Inflector.safe_constantize(name)
    end

    # Determine if the given constant has been automatically loaded.
    def autoloaded?(desc)
      return false if desc.is_a?(Module) && real_mod_name(desc).nil?
      name = to_constant_name desc
      return false unless qualified_const_defined?(name)
      autoloaded_constants.include?(name)
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
        false
      else
        explicitly_unloadable_constants << name
        true
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
      constant_watch_stack.watch_namespaces(descs)
      success = false

      begin
        yield # Now yield to the code that is to define new constants.
        success = true
      ensure
        new_constants = constant_watch_stack.new_constants

        return new_constants if success

        # Remove partially loaded constants.
        new_constants.each { |c| remove_constant(c) }
      end
    end

    # Convert the provided const desc to a qualified constant name (as a string).
    # A module, class, symbol, or string may be provided.
    def to_constant_name(desc) # :nodoc:
      case desc
      when String then desc.delete_prefix("::")
      when Symbol then desc.to_s
      when Module
        real_mod_name(desc) ||
          raise(ArgumentError, "Anonymous modules have no name to be referenced by")
      else raise TypeError, "Not a valid constant descriptor: #{desc.inspect}"
      end
    end

    def remove_constant(const) # :nodoc:
      # Normalize ::Foo, ::Object::Foo, Object::Foo, Object::Object::Foo, etc. as Foo.
      normalized = const.to_s.delete_prefix("::")
      normalized.sub!(/\A(Object::)+/, "")

      constants = normalized.split("::")
      to_remove = constants.pop

      # Remove the file path from the loaded list.
      file_path = search_for_file(const.underscore)
      if file_path
        expanded = File.expand_path(file_path)
        expanded.delete_suffix!(".rb")
        loaded.delete(expanded)
      end

      if constants.empty?
        parent = Object
      else
        # This method is robust to non-reachable constants.
        #
        # Non-reachable constants may be passed if some of the parents were
        # autoloaded and already removed. It is easier to do a sanity check
        # here than require the caller to be clever. We check the parent
        # rather than the very const argument because we do not want to
        # trigger Kernel#autoloads, see the comment below.
        parent_name = constants.join("::")
        return unless qualified_const_defined?(parent_name)
        parent = constantize(parent_name)
      end

      # In an autoloaded user.rb like this
      #
      #   autoload :Foo, 'foo'
      #
      #   class User < ActiveRecord::Base
      #   end
      #
      # we correctly register "Foo" as being autoloaded. But if the app does
      # not use the "Foo" constant we need to be careful not to trigger
      # loading "foo.rb" ourselves. While #const_defined? and #const_get? do
      # require the file, #autoload? and #remove_const don't.
      #
      # We are going to remove the constant nonetheless ---which exists as
      # far as Ruby is concerned--- because if the user removes the macro
      # call from a class or module that were not autoloaded, as in the
      # example above with Object, accessing to that constant must err.
      unless parent.autoload?(to_remove)
        begin
          constantized = parent.const_get(to_remove, false)
        rescue NameError
          # The constant is no longer reachable, just skip it.
          return
        else
          constantized.before_remove_const if constantized.respond_to?(:before_remove_const)
        end
      end

      begin
        parent.instance_eval { remove_const to_remove }
      rescue NameError
        # The constant is no longer reachable, just skip it.
      end
    end

    private
      def uninitialized_constant(qualified_name, const_name, receiver:)
        NameError.new("uninitialized constant #{qualified_name}", const_name, receiver: receiver)
      end

      # Returns the original name of a class or module even if `name` has been
      # overridden.
      def real_mod_name(mod)
        UNBOUND_METHOD_MODULE_NAME.bind_call(mod)
      end
  end
end
