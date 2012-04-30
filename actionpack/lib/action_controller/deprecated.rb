ActionController::AbstractRequest = ActionController::Request = ActionDispatch::Request
ActionController::AbstractResponse = ActionController::Response = ActionDispatch::Response
ActionController::Routing = ActionDispatch::Routing

ActiveSupport::Deprecation.warn 'ActionController::AbstractRequest and ActionController::Request are deprecated and will be removed, use ActionDispatch::Request instead.'
ActiveSupport::Deprecation.warn 'ActionController::AbstractResponse and ActionController::Response are deprecated and will be removed, use ActionDispatch::Response instead.'
ActiveSupport::Deprecation.warn 'ActionController::Routing is deprecated and will be removed, use ActionDispatch::Routing instead.'