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
    ActiveSupport::Deprecation.warn "attr_accessor_with_default is deprecated. Use Ruby instead!"
    define_method(sym, block_given? ? default : Proc.new { default })
    module_eval(<<-EVAL, __FILE__, __LINE__ + 1)
      def #{sym}=(value)                          # def age=(value)
        class << self; attr_accessor :#{sym} end  #   class << self; attr_accessor :age end
        @#{sym} = value                           #   @age = value
      end                                         # end
    EVAL
  end
end
