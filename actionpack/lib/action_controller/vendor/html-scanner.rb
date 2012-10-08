require 'action_view/vendor/html-scanner'
require 'active_support/deprecation'

ActiveSupport::Deprecation.warn 'Vendored html-scanner was moved to action_view, please require "action_view/vendor/html-scanner" instead. ' +
                                'This file will be removed in Rails 4.1'
