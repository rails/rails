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
end

Object.send(:define_method, :require_or_load)     { |file_name| Dependencies.require_or_load(file_name) } unless Object.respond_to?(:require_or_load)
Object.send(:define_method, :require_dependency)  { |file_name| Dependencies.depend_on(file_name) } unless Object.respond_to?(:require_dependency)
Object.send(:define_method, :require_association) { |file_name| Dependencies.associate_with(file_name) } unless Object.respond_to?(:require_association)

class Object #:nodoc:
  class << self
    # Use const_missing to autoload associations so we don't have to
    # require_association when using single-table inheritance.
    def const_missing(class_id)
      begin
        require_or_load(class_id.to_s.demodulize.underscore)
        if Object.const_defined?(class_id) then return Object.const_get(class_id) else raise LoadError end
      rescue LoadError
        raise NameError, "uninitialized constant #{class_id}"
      end
    end
  end
end