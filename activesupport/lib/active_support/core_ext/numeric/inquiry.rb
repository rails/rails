# frozen_string_literal: true

require 'active_support/deprecation'

ActiveSupport::Deprecation.warn 'Ruby 2.5+ (required by Rails 6) provides Numeric#positive? and Numeric#negative? natively, so requiring active_support/core_ext/numeric/inquiry is no longer necessary. Requiring it will raise LoadError in Rails 6.1.'
