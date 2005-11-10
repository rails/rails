require File.dirname(__FILE__) + '/module_attribute_accessors'
require File.dirname(__FILE__) + '/core_ext/load_error'

module Dependencies #:nodoc:
  extend self

  @@loaded = [ ]
  mattr_accessor :loaded

  @@mechanism = :load
  mattr_accessor :mechanism
  
  def load?
    mechanism == :load
  end
  
  def depend_on(file_name, swallow_load_errors = false)
    unless loaded.include?(file_name)
      loaded << file_name

      begin
        require_or_load(file_name)
      rescue LoadError
        raise unless swallow_load_errors
      end
    end
  end

  def associate_with(file_name)
    depend_on(file_name, true)
  end
  
  def clear
    self.loaded = [ ]
  end
  
  def require_or_load(file_name)
    file_name = "#{file_name}.rb" unless ! load? || file_name[-3..-1] == '.rb'
    load? ? load(file_name) : require(file_name)
  end
  
  def remove_subclasses_for(*classes)
    Object.remove_subclasses_of(*classes)
  end
  
  # LoadingModules implement namespace-safe dynamic loading.
  # They support automatic loading via const_missing, allowing contained items to be automatically
  # loaded when required. No extra syntax is required, as expressions such as Controller::Admin::UserController
  # load the relavent files automatically.
  #
  # Ruby-style modules are supported, as a folder named 'submodule' will load 'submodule.rb' when available.
  class LoadingModule < Module #:nodoc:
    attr_reader :path
    attr_reader :root
    
    class << self
      def root(*load_paths)
        RootLoadingModule.new(*load_paths)
      end
    end
    
    def initialize(root, path=[])
      @path = path.clone.freeze
      @root = root
    end
    
    def root?()      self.root == self    end
    def load_paths() self.root.load_paths end
    
    # Load missing constants if possible.
    def const_missing(name)
      const_load!(name) ? const_get(name) : super(name)
    end
  
    # Load the controller class or a parent module.
    def const_load!(name, file_name = nil)
      file_name ||= 'application' if root? && name.to_s == 'ApplicationController'
      path = self.path + [file_name || name]

      load_paths.each do |load_path|
        fs_path = load_path.filesystem_path(path)
        next unless fs_path

        case 
        when File.directory?(fs_path)
          new_module = LoadingModule.new(self.root, self.path + [name])
          self.const_set name, new_module
          if self.root?
            if Object.const_defined?(name)
              msg = "Cannot load module #{name}: Object::#{name} is set to #{Object.const_get(name).inspect}"
              raise NameError, msg
            end
            Object.const_set(name, new_module)
          end
          break
        when File.file?(fs_path)
          loaded_file = self.root.load_file!(fs_path)
          
          # Import the loaded constant from Object provided we are the root node.
          self.const_set(name, Object.const_get(name)) if self.root? && Object.const_defined?(name)
          
          # Throw an error if we load the file but we don't find the Object we expect
          if loaded_file and not self.const_defined?(name)
            msg = "Already loaded file '#{fs_path}' but '#{name.to_s}' was not set, perhaps you need to rename '#{fs_path}'?"
            raise LoadError, msg
          end
          break
        end
      end
      
      self.const_defined?(name)
    end
    
    # Is this name present or loadable?
    # This method is used by Routes to find valid controllers.
    def const_available?(name)
      self.const_defined?(name) || load_paths.any? {|lp| lp.filesystem_path(path + [name])}
    end
  end
  
  class RootLoadingModule < LoadingModule #:nodoc:
    attr_reader :load_paths

    def initialize(*paths)
      @load_paths = paths.flatten.collect {|p| p.kind_of?(ConstantLoadPath) ? p : ConstantLoadPath.new(p)}
    end

    def root() self end

    def path() [] end
    
    # Load the source file at the given file path
    def load_file!(file_path)
      require_dependency(file_path)
    end

    # Erase all items in this module
    def clear!
      constants.each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name) && Object.const_get(name).object_id == self.const_get(name).object_id
        self.send(:remove_const, name)
      end
    end
  end
  
  # This object defines a path from which Constants can be loaded.
  class ConstantLoadPath #:nodoc:
    # Create a new load path with the filesystem path
    def initialize(root) @root = root end
    
    # Return nil if the path does not exist, or the path to a directory
    # if the path leads to a module, or the path to a file if it leads to an object.
    def filesystem_path(path, allow_module=true)
      fs_path = [@root]
      fs_path += path[0..-2].map {|name| const_name_to_module_name name}

      if allow_module
        result = File.join(fs_path, const_name_to_module_name(path.last))
        return result if File.directory? result # Return the module path if one exists
      end

      result = File.join(fs_path, const_name_to_file_name(path.last))

      File.file?(result) ? result : nil
    end
    
    def const_name_to_file_name(name)
      name.to_s.underscore + '.rb'
    end

    def const_name_to_module_name(name)
      name.to_s.underscore
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
    if Object.const_defined?(:Controllers) and Object::Controllers.const_available?(class_id)
      return Object::Controllers.const_get(class_id)
    end
    
    file_name = class_id.to_s.demodulize.underscore
    begin
      require_dependency(file_name)
      raise NameError.new("uninitialized constant #{class_id}") unless Object.const_defined?(class_id)
      return Object.const_get(class_id)
    rescue MissingSourceFile => e
      # Convert the exception to a NameError only if the file we are looking for is the missing one.
      raise unless e.is_missing? file_name
      raise NameError.new("uninitialized constant #{class_id}").copy_blame!(e)
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
