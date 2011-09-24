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
  def return_if(*args, &block)
    nil
  end
end
