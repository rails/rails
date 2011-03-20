class Module
  # Declare an attribute accessor with an initial default return value.
  #
  # To give attribute <tt>:age</tt> the initial value <tt>25</tt>:
  #
  #   class Person
  #     attr_accessor_with_default :age, 25
  #   end
  #
  #   person = Person.new
  #   person.age # => 25
  #
  #   person.age = 26
  #   person.age # => 26
  #
  # To give attribute <tt>:element_name</tt> a dynamic default value, evaluated
  # in scope of self:
  #
  #   attr_accessor_with_default(:element_name) { name.underscore }
  #
  def attr_accessor_with_default(sym, default = Proc.new)
    attr_writer sym
    
    block = block_given? ? default : Proc.new { default }
    define_method(sym) do
      if instance_variable_defined?("@#{sym.to_s}")
        instance_variable_get("@#{sym.to_s}")
      else
        instance_eval(&block)
      end
    end
  end
end
