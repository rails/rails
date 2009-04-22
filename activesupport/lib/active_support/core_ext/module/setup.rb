class Module
  attr_accessor :_setup_block
  attr_accessor :_dependencies
  
  def setup(&blk)
    @_setup_block = blk
  end
  
  def use(mod)
    return if self < mod
    
    (mod._dependencies || []).each do |dep|
      use dep
    end
    # raise "Circular dependencies" if self < mod
    include mod
    extend mod.const_get("ClassMethods") if mod.const_defined?("ClassMethods")
    class_eval(&mod._setup_block) if mod._setup_block
  end
  
  def depends_on(mod)
    return if self < mod
    @_dependencies ||= []
    @_dependencies << mod
  end
end