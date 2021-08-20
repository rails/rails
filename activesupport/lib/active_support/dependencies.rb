# frozen_string_literal: true

require "set"
require "active_support/core_ext/module/attribute_accessors"
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

    def clear
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

    private
      # Returns the original name of a class or module even if `name` has been
      # overridden.
      def real_mod_name(mod)
        UNBOUND_METHOD_MODULE_NAME.bind_call(mod)
      end
  end
end
