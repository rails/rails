class Module
  if instance_methods[0].is_a?(Symbol)
    def instance_method_names(*args)
      instance_methods(*args).map(&:to_s)
    end

    def method_names(*args)
      methods(*args).map(&:to_s)
    end
  else
    alias_method :instance_method_names, :instance_methods
    alias_method :method_names, :methods
  end
end