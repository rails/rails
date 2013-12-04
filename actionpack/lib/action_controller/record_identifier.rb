require 'action_view/record_identifier'

ActiveSupport::Deprecation.warn "'ActionController::RecordIdentifier' is deprecated. Please require 'action_view/record_identifier' and use 'ActionView::RecordIdentifier' instead."
module ActionController
  RecordIdentifier = ActionView::RecordIdentifier
end
