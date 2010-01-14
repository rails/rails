module ActiveModel
  # If your object is already designed to implement all of the Active Model featurs
  # include this module in your Class.
  # 
  #   class MyClass
  #     include ActiveModel::Conversion
  #   end
  # 
  # Returns self to the <tt>:to_model</tt> method.
  # 
  # If your model does not act like an Active Model object, then you should define
  # <tt>:to_model</tt> yourself returning a proxy object that wraps your object
  # with Active Model compliant methods.
  module Conversion
    def to_model
      self
    end
  end
end
