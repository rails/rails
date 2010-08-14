# lazy_load_hooks allows rails to lazily load a lot of components and thus making the app boot faster. Because of
# this feature now there is no need to require <tt>ActiveRecord::Base</tt> at boot time purely to apply configuration. Instead
# a hook is registered that applies configuration once <tt>ActiveRecord::Base</tt> is loaded. Here <tt>ActiveRecord::Base</tt> is used
# as example but this feature can be applied elsewhere too.
#
# Here is an example where +on_load+ method is called to register a hook.
#
#  initializer "active_record.initialize_timezone" do
#    ActiveSupport.on_load(:active_record) do
#      self.time_zone_aware_attributes = true
#      self.default_timezone = :utc
#    end
#  end
#
# When the entirety of +activerecord/lib/active_record/base.rb+ has been evaluated then +run_load_hooks+ is invoked.
# The very last line of +activerecord/lib/active_record/base.rb+ is:
#
#  ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
#
module ActiveSupport
  @load_hooks = Hash.new {|h,k| h[k] = [] }
  @loaded = {}

  def self.on_load(name, options = {}, &block)
    if base = @loaded[name]
      execute_hook(base, options, block)
    else
      @load_hooks[name] << [block, options]
    end
  end

  def self.execute_hook(base, options, block)
    if options[:yield]
      block.call(base)
    else
      base.instance_eval(&block)
    end
  end

  def self.run_load_hooks(name, base = Object)
    @loaded[name] = base
    @load_hooks[name].each do |hook, options|
      execute_hook(base, options, hook)
    end
  end
end
