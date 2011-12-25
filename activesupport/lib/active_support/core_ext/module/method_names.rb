class Module
  def method_names(*args)
    methods(*args).map { |name| name.to_s }
  end
end
