# Extensions to nil which allow for more helpful error messages for 
# people who are new to rails.
#
# The aim is to ensure that when users pass nil to methods where that isn't
# appropriate, instead of NoMethodError and the name of some method used
# by the framework users will see a message explaining what type of object 
# was expected.

class NilClass
  WHINERS = [ ::ActiveRecord::Base, ::Array ]
  
  @@method_class_map = Hash.new
  
  WHINERS.each do |klass|
    methods = klass.public_instance_methods - public_instance_methods
    methods.each do |method|
      @@method_class_map[method.to_sym] = klass
    end
  end
  
  def id
    raise RuntimeError, "Called id for nil, which would mistakenly be 4 -- if you really wanted the id of nil, use object_id", caller
  end

  private
    def method_missing(method, *args, &block)
      raise_nil_warning_for @@method_class_map[method], method, caller
    end

    def raise_nil_warning_for(klass = nil, selector = nil, with_caller = nil)
      message = "You have a nil object when you didn't expect it!"
      message << "\nYou might have expected an instance of #{klass}." if klass
      message << "\nThe error occurred while evaluating nil.#{selector}" if selector
      
      raise NoMethodError, message, with_caller || caller
    end
end

