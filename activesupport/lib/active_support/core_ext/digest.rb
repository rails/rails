# frozen_string_literal: true

require "active_support/core_ext/digest/uuid"

module ActiveSupport
  class << self
    delegate :use_rfc4122_namespaced_uuids, :use_rfc4122_namespaced_uuids=, to: :'Digest::UUID'
  end
end
