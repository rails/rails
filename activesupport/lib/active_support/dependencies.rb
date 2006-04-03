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

  def load?
    mechanism == :load
  end

  def depend_on(file_name, swallow_load_errors = false)
    require_or_load(file_name)
  rescue LoadError
    raise unless swallow_load_errors
  end

  def associate_with(file_name)
    depend_on(file_name, true)
  end

  def clear
    loaded.clear
  end

  def require_or_load(file_name)
    file_name = $1 if file_name =~ /^(.*)\.rb$/
    return if loaded.include?(file_name)

    # Record that we've seen this file *before* loading it to avoid an
    # infinite loop with mutual dependencies.
    loaded << file_name

    if load?
      begin
        # Enable warnings iff this file has not been loaded before and
        # warnings_on_first_load is set.
        if !warnings_on_first_load or history.include?(file_name)
          load "#{file_name}.rb"
        else
          enable_warnings { load "#{file_name}.rb" }
        end
      rescue
        loaded.delete file_name
        raise
      end
    else
      require file_name
    end

    # Record history *after* loading so first load gets warnings.
    history << file_name
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
    file_name = class_id.to_s.demodulize.underscore
    file_path = as_load_path.empty? ? file_name : "#{as_load_path}/#{file_name}"
    begin
      require_dependency(file_path)
      brief_name = self == Object ? '' : "#{name}::"
      raise NameError.new("uninitialized constant #{brief_name}#{class_id}") unless const_defined?(class_id)
      return const_get(class_id)
    rescue MissingSourceFile => e
      # Re-raise the error if it does not concern the file we were trying to load.
      raise unless e.is_missing? file_path
      
      # Look for a directory in the load path that we ought to load.
      if $LOAD_PATH.any? { |base| File.directory? "#{base}/#{file_path}" }
        mod = Module.new
        const_set class_id, mod # Create the new module
        return mod
      end
      
      # Attempt to access the name from the parent, unless we don't have a valid
      # parent, or the constant is already defined in the parent. If the latter
      # is the case, then we are being queried via self::class_id, and we should
      # avoid returning the constant from the parent if possible.
      if parent && parent != self && ! parents.any? { |p| p.const_defined?(class_id) }
        suppress(NameError) do
          return parent.send(:const_missing, class_id)
        end
      end
      
      raise NameError.new("uninitialized constant #{class_id}").copy_blame!(e)
    end
  end
end

class Class
  def const_missing(class_id)
    if [Object, Kernel].include?(self) || parent == self
      super
    else
      parent.send :const_missing, class_id
    end
  end
end

class Object #:nodoc:
  def load(file, *extras)
    super(file, *extras)
  rescue Object => exception
    exception.blame_file! file
    raise
  end

  def require(file, *extras)
    super(file, *extras)
  rescue Object => exception
    exception.blame_file! file
    raise
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
    "This error occured while loading the following files:\n   #{blamed_files.join "\n   "}"
  end

  def copy_blame!(exc)
    @blamed_files = exc.blamed_files.clone
    self
  end
end