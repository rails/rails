class SqlBuilderAdapter
  instance_methods.each { |m| undef_method m unless m =~ /^__|^instance_eval|class/ }
    
  def initialize(adaptee, &block)
    @adaptee = adaptee
    (class << self; self end).class_eval do
      (adaptee.methods - instance_methods).each { |m| delegate m, :to => :@adaptee }
    end
    (class << self; self end).instance_exec(@adaptee, &block)
  end
  
  def call(&block)
    @caller = eval("self", block.binding)
    returning self do |adapter|
      instance_eval(&block)
    end
  end
  
  def method_missing(method, *args, &block)
    @caller.send(method, *args, &block)
  end
end