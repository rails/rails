module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    extend ActiveSupport::Concern

    included do
      ActiveSupport::Deprecation.warn "ActionController::SessionManagement " \
       "is deprecated because it has no contents since Rails 3.1", caller
    end

    module ClassMethods

    end
  end
end
