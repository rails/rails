# frozen_string_literal: true

require 'active_support/deprecation'

ActiveSupport::Deprecation.warn 'Ruby 2.5+ (required by Rails 6) provides Hash#transform_values natively, so requiring active_support/core_ext/hash/transform_values is no longer necessary. Requiring it will raise LoadError in Rails 6.1.'
