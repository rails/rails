require 'set'
require File.dirname(__FILE__) + '/core_ext/module/attribute_accessors'
require File.dirname(__FILE__) + '/core_ext/load_error'
require File.dirname(__FILE__) + '/core_ext/kernel'

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
  self.mechanism = :load
  
  # The set of directories from which we may automatically load files. Files
  # under these directories will be reloaded on each request in development mode,
  # unless the directory also appears in load_once_paths.
  mattr_accessor :load_paths
  self.load_paths = []
  
  # The set of directories from which automatically loaded constants are loaded
  # only once. All directories in this set must also be present in +load_paths+.
  mattr_accessor :load_once_paths
  self.load_once_paths = []
  
  # An array of qualified constant names that have been loaded. Adding a name to
  # this array will cause it to be unloaded the next time Dependencies are cleared.
  mattr_accessor :autoloaded_constants
  self.autoloaded_constants = []
  
  # An array of constant names that need to be unloaded on every request. Used
  # to allow arbitrary constants to be marked for unloading.
  mattr_accessor :explicitly_unloadable_constants
  self.explicitly_unloadable_constants = []
  
  # Set to true to enable logging of const_missing and file loads
  mattr_accessor :log_activity
  self.log_activity = false
  
  # :nodoc:
  # An internal stack used to record which constants are loaded by any block.
  mattr_accessor :constant_watch_stack
  self.constant_watch_stack = []
  
  def load?
    mechanism == :load
  end

  def depend_on(file_name, swallow_load_errors = false)
    path = search_for_file(file_name)
    require_or_load(path || file_name)
  rescue LoadError
    raise unless swallow_load_errors
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
    
    if load?
      log "loading #{file_name}"
      begin
        # Enable warnings iff this file has not been loaded before and
        # warnings_on_first_load is set.
        load_args = ["#{file_name}.rb"]
        load_args << const_path unless const_path.nil?
        
        if !warnings_on_first_load or history.include?(expanded)
          result = load_file(*load_args)
        else
          enable_warnings { result = load_file(*load_args) }
        end
      rescue Exception
        loaded.delete expanded
        raise
      end
    else
      log "requiring #{file_name}"
      result = require file_name
    end

    # Record history *after* loading so first load gets warnings.
    history << expanded
    return result
  end
  
  # Is the provided constant path defined?
  def qualified_const_defined?(path)
    raise NameError, "#{path.inspect} is not a valid constant name!" unless
      /^(::)?([A-Z]\w*)(::[A-Z]\w*)*$/ =~ path
    
    names = path.split('::')
    names.shift if names.first.empty?
    
    # We can't use defined? because it will invoke const_missing for the parent
    # of the name we are checking.
    names.inject(Object) do |mod, name|
      return false unless mod.const_defined? name
      mod.const_get name
    end
    return true
  end
  
  # Given +path+, a filesystem path to a ruby file, return an array of constant
  # paths which would cause Dependencies to attempt to load this file.
  # 
  def loadable_constants_for_path(path, bases = load_paths - load_once_paths)
    path = $1 if path =~ /\A(.*)\.rb\Z/
    expanded_path = File.expand_path(path)
    
    bases.collect do |root|
      expanded_root = File.expand_path(root)
      next unless %r{\A#{Regexp.escape(expanded_root)}(/|\\)} =~ expanded_path
      
      nesting = expanded_path[(expanded_root.size)..-1]
      nesting = nesting[1..-1] if nesting && nesting[0] == ?/
      next if nesting.blank?
      
      [
        nesting.camelize,
        # Special case: application.rb might define ApplicationControlller.
        ('ApplicationController' if nesting == 'application')
      ]
    end.flatten.compact.uniq
  end
  
  # Search for a file in load_paths matching the provided suffix.
  def search_for_file(path_suffix)
    path_suffix = path_suffix + '.rb' unless path_suffix.ends_with? '.rb'
    load_paths.each do |root|
      path = File.join(root, path_suffix)
      return path if File.file? path
    end
    nil # Gee, I sure wish we had first_match ;-)
  end
  
  # Does the provided path_suffix correspond to an autoloadable module?
  # Instead of returning a boolean, the autoload base for this module is returned. 
  def autoloadable_module?(path_suffix)
    load_paths.each do |load_path|
      return load_path if File.directory? File.join(load_path, path_suffix)
    end
    nil
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
    autoloaded_constants << qualified_name unless load_once_paths.include?(base_path)
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
      result = load_without_new_constant_marking path
    end
    
    autoloaded_constants.concat newly_defined_paths
    autoloaded_constants.uniq!
    log "loading #{path} defined #{newly_defined_paths * ', '}" unless newly_defined_paths.empty?
    return result
  end
  
  # Return the constant path for the provided parent and constant name.
  def qualified_name_for(mod, name)
    mod_name = to_constant_name mod
    (%w(Object Kernel).include? mod_name) ? name.to_s : "#{mod_name}::#{name}"
  end
  
  # Load the constant named +const_name+ which is missing from +from_mod+. If
  # it is not possible to laod the constant into from_mod, try its parent module
  # using const_missing.
  def load_missing_constant(from_mod, const_name)
    log_call from_mod, const_name
    if from_mod == Kernel
      if ::Object.const_defined?(const_name)
        log "Returning Object::#{const_name} for Kernel::#{const_name}"
        return ::Object.const_get(const_name)
      else
        log "Substituting Object for Kernel"
        from_mod = Object
      end
    end
    
    # If we have an anonymous module, all we can do is attempt to load from Object.
    from_mod = Object if from_mod.name.empty?
    
    unless qualified_const_defined?(from_mod.name) && from_mod.name.constantize.object_id == from_mod.object_id
      raise ArgumentError, "A copy of #{from_mod} has been removed from the module tree but is still active!"
    end
    
    raise ArgumentError, "#{from_mod} is not missing constant #{const_name}!" if from_mod.const_defined?(const_name)
    
    qualified_name = qualified_name_for from_mod, const_name
    path_suffix = qualified_name.underscore
    name_error = NameError.new("uninitialized constant #{qualified_name}")
    
    file_path = search_for_file(path_suffix)
    if file_path && ! loaded.include?(File.expand_path(file_path)) # We found a matching file to load
      require_or_load file_path
      raise LoadError, "Expected #{file_path} to define #{qualified_name}" unless from_mod.const_defined?(const_name)
      return from_mod.const_get(const_name)
    elsif mod = autoload_module!(from_mod, const_name, qualified_name, path_suffix)
      return mod
    elsif (parent = from_mod.parent) && parent != from_mod &&
          ! from_mod.parents.any? { |p| p.const_defined?(const_name) }
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
  # marked for unloading.
  def remove_unloadable_constants!
    autoloaded_constants.each { |const| remove_constant const }
    autoloaded_constants.clear
    explicitly_unloadable_constants.each { |const| remove_constant const }
  end
  
  # Determine if the given constant has been automatically loaded.
  def autoloaded?(desc)
    name = to_constant_name desc
    return false unless qualified_const_defined? name
    return autoloaded_constants.include?(name)
  end
  
  # Will the provided constant descriptor be unloaded?
  def will_unload?(const_desc)
    autoloaded?(desc) ||
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
    
    # Build the watch frames. Each frame is a tuple of
    #   [module_name_as_string, constants_defined_elsewhere]
    watch_frames = descs.collect do |desc|
      if desc.is_a? Module
        mod_name = desc.name
        initial_constants = desc.constants
      elsif desc.is_a?(String) || desc.is_a?(Symbol)
        mod_name = desc.to_s
        
        # Handle the case where the module has yet to be defined.
        initial_constants = if qualified_const_defined?(mod_name)
          mod_name.constantize.constants
        else
         []
        end
      else
        raise Argument, "#{desc.inspect} does not describe a module!"
      end
      
      [mod_name, initial_constants]
    end
    
    constant_watch_stack.concat watch_frames
    
    aborting = true
    begin
      yield # Now yield to the code that is to define new constants.
      aborting = false
    ensure
      # Find the new constants.
      new_constants = watch_frames.collect do |mod_name, prior_constants|
        # Module still doesn't exist? Treat it as if it has no constants.
        next [] unless qualified_const_defined?(mod_name)
        
        mod = mod_name.constantize
        next [] unless mod.is_a? Module
        new_constants = mod.constants - prior_constants
        
        # Make sure no other frames takes credit for these constants.
        constant_watch_stack.each do |frame_name, constants|
          constants.concat new_constants if frame_name == mod_name
        end
        
        new_constants.collect do |suffix|
          mod_name == "Object" ? suffix : "#{mod_name}::#{suffix}"
        end
      end.flatten
      
      log "New constants: #{new_constants * ', '}"
      
      if aborting
        log "Error during loading, removing partially loaded constants "
        new_constants.each { |name| remove_constant name }
        new_constants.clear
      end
    end
    
    return new_constants
  ensure
    # Remove the stack frames that we added.
    if defined?(watch_frames) && ! watch_frames.empty?
      frame_ids = watch_frames.collect(&:object_id)
      constant_watch_stack.delete_if do |watch_frame|
        frame_ids.include? watch_frame.object_id
      end
    end
  end
  
  class LoadingModule
    # Old style environment.rb referenced this method directly.  Please note, it doesn't
    # actualy *do* anything any more.
    def self.root(*args)
      if defined?(RAILS_DEFAULT_LOGGER)
        RAILS_DEFAULT_LOGGER.warn "Your environment.rb uses the old syntax, it may not continue to work in future releases."
        RAILS_DEFAULT_LOGGER.warn "For upgrade instructions please see: http://manuals.rubyonrails.com/read/book/19"
      end
    end
  end

protected
  
  # Convert the provided const desc to a qualified constant name (as a string).
  # A module, class, symbol, or string may be provided.
  def to_constant_name(desc)
    name = case desc
      when String then desc.starts_with?('::') ? desc[2..-1] : desc
      when Symbol then desc.to_s
      when Module
        raise ArgumentError, "Anonymous modules have no name to be referenced by" if desc.name.blank?
        desc.name
      else raise TypeError, "Not a valid constant descriptor: #{desc.inspect}"
    end
  end
  
  def remove_constant(const)
    return false unless qualified_const_defined? const
    
    names = const.split('::')
    if names.size == 1 || names.first.empty? # It's under Object
      parent = Object
    else
      parent = (names[0..-2] * '::').constantize
    end
    
    log "removing constant #{const}"
    parent.send :remove_const, names.last
    return true
  end
  
  def log_call(*args)
    arg_str = args.collect(&:inspect) * ', '
    /in `([a-z_\?\!]+)'/ =~ caller(1).first
    selector = $1 || '<unknown>' 
    log "called #{selector}(#{arg_str})"
  end
  
  def log(msg)
    if defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER && log_activity
      RAILS_DEFAULT_LOGGER.debug "Dependencies: #{msg}"
    end
  end
  
end

Object.send(:define_method, :require_or_load)     { |file_name| Dependencies.require_or_load(file_name) } unless Object.respond_to?(:require_or_load)
Object.send(:define_method, :require_dependency)  { |file_name| Dependencies.depend_on(file_name) }       unless Object.respond_to?(:require_dependency)
Object.send(:define_method, :require_association) { |file_name| Dependencies.associate_with(file_name) }  unless Object.respond_to?(:require_association)

class Module #:nodoc:
  # Rename the original handler so we can chain it to the new one
  alias :rails_original_const_missing :const_missing
  
  # Use const_missing to autoload associations so we don't have to
  # require_association when using single-table inheritance.
  def const_missing(class_id)
    Dependencies.load_missing_constant self, class_id
  end
  
  def unloadable(const_desc = self)
    super(const_desc)
  end
  
end

class Class
  def const_missing(class_id)
    if [Object, Kernel].include?(self) || parent == self
      super
    else
      begin
        begin
          Dependencies.load_missing_constant self, class_id
        rescue NameError
          parent.send :const_missing, class_id
        end
      rescue NameError => e
        # Make sure that the name we are missing is the one that caused the error
        parent_qualified_name = Dependencies.qualified_name_for parent, class_id
        raise unless e.missing_name? parent_qualified_name
        qualified_name = Dependencies.qualified_name_for self, class_id
        raise NameError.new("uninitialized constant #{qualified_name}").copy_blame!(e)
      end
    end
  end
end

class Object #:nodoc:
  
  alias_method :load_without_new_constant_marking, :load
  
  def load(file, *extras)
    Dependencies.new_constants_in(Object) { super(file, *extras) }
  rescue Exception => exception  # errors from loading file
    exception.blame_file! file
    raise
  end

  def require(file, *extras)
    Dependencies.new_constants_in(Object) { super(file, *extras) }
  rescue Exception => exception  # errors from required file
    exception.blame_file! file
    raise
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

# Add file-blaming to exceptions
class Exception #:nodoc:
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
