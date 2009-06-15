require "active_support/core_ext/object"

class Proc #:nodoc:
  def bind(object)
    block, time = self, Time.now
    object.class_eval do
      method_name = "__bind_#{time.to_i}_#{time.usec}"
      define_method(method_name, &block)     # define_method("__bind_1230458026_720454", &block)
      method = instance_method(method_name)  # method = instance_method("__bind_1230458026_720454")
      remove_method(method_name)             # remove_method("__bind_1230458026_720454")
      method
    end.bind(object)
  end
end
