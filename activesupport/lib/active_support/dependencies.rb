require File.dirname(__FILE__) + '/module_attribute_accessors'

module Dependencies
  extend self

  @@loaded = [ ]
  mattr_accessor :loaded

  @@mechanism = :load
  mattr_accessor :mechanism
  
  def load?
    mechanism == :load
  end
  
  def depend_on(file_name, swallow_load_errors = false)
    if !loaded.include?(file_name)
      loaded << file_name
      begin
        require_or_load(file_name)
      rescue LoadError
        raise unless swallow_load_errors
      rescue Object => e
        raise ScriptError, "#{e.message}"
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
    load? ? load("#{file_name}.rb") : require(file_name)
  end
  
  def remove_subclasses_for(*classes)
    classes.each { |klass| klass.remove_subclasses }
  end
  
  # LoadingModules implement namespace-safe dynamic loading.
  # They support automatic loading via const_missing, allowing contained items to be automatically
  # loaded when required. No extra syntax is required, as expressions such as Controller::Admin::UserController
  # load the relavent files automatically.
  #
  # Ruby-style modules are supported, as a folder named 'submodule' will load 'submodule.rb' when available.
  class LoadingModule < Module
    attr_reader :path

    def initialize(filesystem_root, path=[])
      @path = path
      @filesystem_root = filesystem_root
    end

    # The path to this module in the filesystem.
    # Any subpath provided is taken to be composed of filesystem names.
    def filesystem_path(subpath=[])
      File.join(@filesystem_root, self.path, subpath)
    end

    # Load missing constants if possible.
    def const_missing(name)
      return const_get(name) if const_defined?(name) == false && const_load!(name)
      super(name)
    end

    # Load the controller class or a parent module.
    def const_load!(name)
      name = name.to_s if name.kind_of? Symbol

      if File.directory? filesystem_path(name.underscore)
        # Is it a submodule? If so, create a new LoadingModule *before* loading it.
        # This ensures that subitems will be loadable
        new_module = LoadingModule.new(@filesystem_root, self.path + [name.underscore])
        const_set(name, new_module)
        Object.const_set(name, new_module) if @path.empty?
      end
      
      source_file = filesystem_path("#{(name == 'ApplicationController' ? 'Application' : name).underscore}.rb")
      self.load_file(source_file) if File.file?(source_file)
      self.const_defined?(name.camelize)
    end

    # Is this name present or loadable?
    # This method is used by Routes to find valid controllers.
    def const_available?(name)
      name = name.to_s unless name.kind_of? String
      File.directory?(filesystem_path(name.underscore)) || File.file?(filesystem_path("#{name.underscore}.rb"))
    end

    def clear
      constants.each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name) && @path.empty?
        self.send(:remove_const, name)
      end
    end

    def load_file(file_path)
      Controllers.module_eval(IO.read(file_path), file_path, 1) # Hard coded Controller line here!!!
    end
  end
end

Object.send(:define_method, :require_or_load)     { |file_name| Dependencies.require_or_load(file_name) } unless Object.respond_to?(:require_or_load)
Object.send(:define_method, :require_dependency)  { |file_name| Dependencies.depend_on(file_name) } unless Object.respond_to?(:require_dependency)
Object.send(:define_method, :require_association) { |file_name| Dependencies.associate_with(file_name) } unless Object.respond_to?(:require_association)

class Object #:nodoc:
  class << self
    # Use const_missing to autoload associations so we don't have to
    # require_association when using single-table inheritance.
    def const_missing(class_id)
      if Object.const_defined?(:Controllers) and Object::Controllers.const_available?(class_id)
        return Object::Controllers.const_get(class_id)
      end
      begin
        require_or_load(class_id.to_s.demodulize.underscore)
        if Object.const_defined?(class_id) then return Object.const_get(class_id) else raise LoadError end
      rescue LoadError
        raise NameError, "uninitialized constant #{class_id}"
      end
    end
  end
end