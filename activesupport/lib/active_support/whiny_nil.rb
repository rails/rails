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
      if @@method_class_map.include?(method)
        raise_nil_warning_for @@method_class_map[method], caller
      else
        super
      end
    end

    def raise_nil_warning_for(klass, with_caller = nil)
      raise NoMethodError, NIL_WARNING_MESSAGE % klass, with_caller || caller
    end

    NIL_WARNING_MESSAGE = <<-end_message unless const_defined?(:NIL_WARNING_MESSAGE)
WARNING:  You have a nil object when you probably didn't expect it!  Odds are you
want an instance of %s instead.

Look in the callstack to see where you're working with an object that could be nil.
Investigate your methods and make sure the object is what you expect!
    end_message
end

