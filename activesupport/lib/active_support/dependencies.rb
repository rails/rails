# frozen_string_literal: true

require "set"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/dependencies/interlock"

module ActiveSupport # :nodoc:
  module Dependencies # :nodoc:
    require_relative "dependencies/require_dependency"

    mattr_accessor :interlock, default: Interlock.new

    # :doc:

    # Execute the supplied block without interference from any
    # concurrent loads.
    def self.run_interlock
      interlock.running { yield }
    end

    # Execute the supplied block while holding an exclusive lock,
    # preventing any other thread from being inside a #run_interlock
    # block at the same time.
    def self.load_interlock
      interlock.loading { yield }
    end

    # Execute the supplied block while holding an exclusive lock,
    # preventing any other thread from being inside a #run_interlock
    # block at the same time.
    def self.unload_interlock
      interlock.unloading { yield }
    end

    # :nodoc:

    # The array of directories from which we autoload and reload, if reloading
    # is enabled. The public interface to push directories to this collection
    # from applications or engines is config.autoload_paths.
    #
    # This collection is allowed to have intersection with autoload_once_paths.
    # Common directories are not reloaded.
    mattr_accessor :autoload_paths, default: []

    # The array of directories from which we autoload and never reload, even if
    # reloading is enabled. The public interface to push directories to this
    # collection from applications or engines is config.autoload_once_paths.
    mattr_accessor :autoload_once_paths, default: []

    # This is a private set that collects all eager load paths during bootstrap.
    # Useful for Zeitwerk integration. The public interface to push custom
    # directories to this collection is from applications or engines is
    # config.eager_load_paths.
    mattr_accessor :_eager_load_paths, default: Set.new

    # If reloading is enabled, this private set holds autoloaded classes tracked
    # by the descendants tracker. It is populated by an on_load callback in the
    # main autoloader. Used to clear state.
    mattr_accessor :_autoloaded_tracked_classes, default: Set.new

    # Private method that reloads constants autoloaded by the main autoloader.
    #
    # Rails.application.reloader.reload! is the public interface for application
    # reload. That involves more things, like deleting unloaded classes from the
    # internal state of the descendants tracker, or reloading routes.
    def self.clear
      unload_interlock do
        _autoloaded_tracked_classes.clear
        Rails.autoloaders.main.reload
      rescue Zeitwerk::ReloadingDisabledError
        raise "reloading is disabled because config.cache_classes is true"
      end
    end

    # Private method used by require_dependency.
    def self.search_for_file(relpath)
      relpath += ".rb" unless relpath.end_with?(".rb")
      autoload_paths.each do |autoload_path|
        abspath = File.join(autoload_path, relpath)
        return abspath if File.file?(abspath)
      end
      nil
    end

    # Private method that helps configuring the autoloaders.
    def self.eager_load?(path)
      _eager_load_paths.member?(path)
    end
  end
end
