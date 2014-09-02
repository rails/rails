require 'active_support/deprecation/proxy_wrappers'

module Rails
  class DeprecatedConstant < ActiveSupport::Deprecation::DeprecatedConstantProxy
    def self.deprecate(old, current)
      # double assignment is used to avoid "assigned but unused variable" warning
      constant = constant = new(old, current)
      eval "::#{old} = constant"
    end

    private

    def target
      ::Kernel.eval @new_const.to_s
    end
  end

  DeprecatedConstant.deprecate('RAILS_CACHE', '::Rails.cache')
end
