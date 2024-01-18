# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActionDispatch
  class Flash
    def self.new(app) app; end
  end
end
