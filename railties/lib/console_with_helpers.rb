module Kernel
  def include_all_modules_from(parent_module)
    parent_module.constants.each do |const|
      mod = parent_module.const_get(const)
      if mod.class == Module
        send(:include, mod)
        include_all_modules_from(mod)
      end
    end
  end
end

require 'application'
@controller = ApplicationController.new
include_all_modules_from ActionView
