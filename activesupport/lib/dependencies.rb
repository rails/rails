require File.dirname(__FILE__) + '/module_attribute_accessors'

module Dependencies
  extend self
  
  @@loaded = [ ]
  mattr_accessor :loaded

  @@mechanism = :load
  mattr_accessor :mechanism
  
  def depend_on(file_name, swallow_load_errors = false)
    if !loaded.include?(file_name)
      begin
        require_or_load(file_name)
        loaded << file_name
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
  
  def reload
    loaded.each do |file_name| 
      begin
        silence_warnings { load("#{file_name}.rb") }
      rescue LoadError
        # We don't care if the file was removed now
      end
    end
  end
  
  def require_or_load(file_name)
    mechanism == :load ? silence_warnings { load("#{file_name}.rb") } : require(file_name)
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
        require_dependency(Inflector.underscore(Inflector.demodulize(class_id.to_s)))
        if Object.const_defined?(class_id) then return Object.const_get(class_id) else raise LoadError end
      rescue LoadError
        raise NameError, "uninitialized constant #{class_id}"
      end
    end
  end
end