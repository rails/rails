# frozen_string_literal: true

require "active_support/deprecation"

ActiveSupport::Deprecation.warn "Ruby 2.4+ (required by Rails 6) provides Hash#compact and Hash#compact! natively, so requiring active_support/core_ext/hash/compact is no longer necessary. Requiring it will raise LoadError in Rails 6.1."
