module ActiveSupport
  module LazyLoadHooks
    def _setup_base_hooks
      @base_hooks ||= Hash.new {|h,k| h[k] = [] }
      @base ||= {}
    end

    def base_hook(name = nil, &block)
      _setup_base_hooks

      if base = @base[name]
        base.instance_eval(&block)
      else
        @base_hooks[name] << block
      end
    end

    def run_base_hooks(base, name = nil)
      _setup_base_hooks

      @base_hooks[name].each { |hook| base.instance_eval(&hook) } if @base_hooks
      @base[name] = base
    end
  end
end