class Object
  def return_if(*args, &block)
    unless args.empty?
      return return_if { |obj| obj.__send__(*args) }
    end

    (yield(self) || nil) && self
  end
end

class NilClass
  def return_if(*args, &block)
    nil
  end
end
