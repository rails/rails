# frozen_string_literal: true

module ActiveSupport
  # = Module Load Hooks
  #
  # ModuleLoadHooks allows \Rails to execute code when an autoloaded module is loaded.
  # This is preferable to using `to_prepare` or other ways of loading code immediately
  # because it doesn't eagerly load constants. When booting a \Rails application,
  # there is no guarantee that any autoloadable code will be needed, so it is best to
  # keep configuration within individual autoloaded files or module level callbacks.
  #
  # Here is an example where on_module_load method is called to register a hook.
  #
  #   initializer 'my_library.configure_class' do
  #     ActiveSupport.on_module_load(config.my_library.class_name) do
  #       self.some_config = true
  #     end
  #   end
  #
  # When the specified class name has been loaded by the Zeitwerk autoloader,
  # the block will be executed. You may set a custom autoloader with the autoloader
  # accessor:
  #
  #   ActiveSupport.autoloader = MY_ZEITWERK_LOADER
  #
  # \Rails will default to using its main Zeitwerk autoloader, but if this feature is needed
  # outside of \Rails, then ActiveSupport.autoloader must be set manually.
  module ModuleLoadHooks
    self.attr_accessor :autoloader

    # Declares a block that will be executed when an autoloadable module is fully
    # loaded. If the module has already loaded, the block is executed
    # immediately.
    def on_module_load(name, &block)
      raise NotImplementedError, "#{self}.autoloader must be set." unless autoloader
      autoloader.on_load(name.to_s) do |mod|
        mod.module_eval(&block)
      end
    end
  end

  extend ModuleLoadHooks
end
