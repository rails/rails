class Object
  def return_if(*args, &block)
    unless args.empty?
      methods     = args.first.to_s.split('.')
      params      = args[1..-1]
      last_method = methods.pop

      result = methods.inject(self) do |acc, method_name|
        acc.try(method_name)
      end

      return return_if { result.try(last_method, *params, &block) }
    end

    (yield(self) || nil) && self
  end
end

class NilClass
  # Calling +return_if+ on +nil+ always returns +nil+.
  # It becomes specially helpful when combining predicates that may return +false+, and thus +return_if+ would return +nil+.
  #
  # === Examples
  #
  #   nil.return_if(:valid?) # => nil
  #   nil.return_if('children.include?', joe) # => nil
  #
  # Without +return_if+
  #   if @person && @person.valid?
  #     @person
  #   else
  #     nil
  #   end
  #
  # Slightly better with +try+
  #   @person.try(:valid?) && @person
  #
  # With +return_if+
  #   @person.return_if(:valid?)
  #
  def return_if(*args, &block)
    nil
  end
end
