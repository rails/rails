class Module
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

def helper(*helper_names)
  returning @helper_proxy ||= Object.new do |helper|
    helper_names.each { |h| helper.extend "#{h}_helper".classify.constantize }
  end
end

require_dependency 'application'

class << helper 
  include_all_modules_from ActionView
end

@controller = ApplicationController.new
helper :application rescue nil
