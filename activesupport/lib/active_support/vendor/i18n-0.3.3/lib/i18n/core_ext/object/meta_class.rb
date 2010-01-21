Object.class_eval do
  def meta_class
    class << self; self; end
  end
end unless Object.method_defined?(:meta_class)
