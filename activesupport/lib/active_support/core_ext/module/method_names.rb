class Module
  def instance_method_names(*args)
    instance_methods(*args).map { |name| name.to_s }
  end

  def method_names(*args)
    methods(*args).map { |name| name.to_s }
  end
end
