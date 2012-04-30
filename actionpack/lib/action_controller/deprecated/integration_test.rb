ActionController::Integration = ActionDispatch::Integration
ActionController::IntegrationTest = ActionDispatch::IntegrationTest

ActiveSupport::Deprecation.warn 'ActionController::Integration is deprecated and will be removed, use ActionDispatch::Integration instead.'
ActiveSupport::Deprecation.warn 'ActionController::IntegrationTest is deprecated and will be removed, use ActionDispatch::IntegrationTest instead.'
