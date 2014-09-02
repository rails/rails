class Module
  ###
  # TODO: remove this after 1.9 support is dropped
  def methods_transplantable? # :nodoc:
    x = Module.new { def foo; end }
    Module.new { define_method :bar, x.instance_method(:foo) }
    true
  rescue TypeError
    false
  end
end
