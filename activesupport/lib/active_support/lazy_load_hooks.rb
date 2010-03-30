module ActiveSupport
  @load_hooks = Hash.new {|h,k| h[k] = [] }
  @loaded = {}

  def self.on_load(name, &block)
    if base = @loaded[name]
      base.instance_eval(&block)
    else
      @load_hooks[name] << block
    end
  end

  def self.run_load_hooks(name, base = Object)
    @load_hooks[name].each { |hook| base.instance_eval(&hook) }
    @loaded[name] = base
  end
end