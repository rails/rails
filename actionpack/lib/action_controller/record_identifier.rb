require 'active_support/deprecation'
require 'action_view/record_identifier'

module ActionController
  module RecordIdentifier
    MESSAGE = 'method will no longer be included by default in controllers since Rails 4.1. ' +
              'If you would like to use it in controllers, please include ' +
              'ActionView::RecodIdentifier module.'

    def dom_id(record, prefix = nil)
      ActiveSupport::Deprecation.warn 'dom_id ' + MESSAGE
      ActionView::RecordIdentifier.dom_id(record, prefix)
    end

    def dom_class(record, prefix = nil)
      ActiveSupport::Deprecation.warn 'dom_class ' + MESSAGE
      ActionView::RecordIdentifier.dom_class(record, prefix)
    end
  end
end
