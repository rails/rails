require 'active_support/deprecation'
require 'action_view/record_identifier'

module ActionController
  RecordIdentifier = ActionView::RecordIdentifier
  ActiveSupport::Deprecation.warn "ActionController::RecordIdentifier was renamed to ActionView::RecordIdentifier. " +
                                  "Please use it instead. ActionController::RecordIdentifier will be removed in Rails 4.1"
end
