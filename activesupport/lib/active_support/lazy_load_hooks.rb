module ActiveSupport
  # lazy_load_hooks allows Rails to lazily load a lot of components and thus
  # making the app boot faster. Because of this feature now there is no need to
  # require <tt>ActiveRecord::Base</tt> at boot time purely to apply
  # configuration. Instead a hook is registered that applies configuration once
  # <tt>ActiveRecord::Base</tt> is loaded. Here <tt>ActiveRecord::Base</tt> is
  # used as example but this feature can be applied elsewhere too.
  #
  # Here is an example where +on_load+ method is called to register a hook.
  #
  #   initializer 'active_record.initialize_timezone' do
  #     ActiveSupport.on_load(:active_record) do
  #       self.time_zone_aware_attributes = true
  #       self.default_timezone = :utc
  #     end
  #   end
  #
  # When the entirety of +ActiveRecord::Base+ has been
  # evaluated then +run_load_hooks+ is invoked. The very last line of
  # +ActiveRecord::Base+ is:
  #
  #   ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
  module LazyLoadHooks
    def self.extended(base) # :nodoc:
      base.class_eval do
        @load_hooks = Hash.new { |h, k| h[k] = [] }
        @loaded     = Hash.new { |h, k| h[k] = [] }
      end
    end

    # Declares a block that will be executed when a Rails component is fully
    # loaded.
    def on_load(name, options = {}, &block)
      @loaded[name].each do |base|
        execute_hook(base, options, block)
      end

      @load_hooks[name] << [block, options]
    end

    def execute_hook(base, options, block)
      if options[:yield]
        block.call(base)
      else
        base.instance_eval(&block)
      end
    end

    def run_load_hooks(name, base = Object)
      @loaded[name] << base
      @load_hooks[name].each do |hook, options|
        execute_hook(base, options, hook)
      end
    end
  end

  extend LazyLoadHooks
end
