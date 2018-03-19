# frozen_string_literal: true

module ActiveRecord
  module ForeignKeys
    # The prefix used by Rails to name unnamed foreign keys.
    PREFIX = "fk_rails"

    # Default regular expression used by Rails to determine if a foreign key
    # name was generated.
    DEFAULT_IGNORE_PATTERN = /^#{PREFIX}_[0-9a-f]{10}$/
  end
end
