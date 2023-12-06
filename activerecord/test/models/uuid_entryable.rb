# frozen_string_literal: true

require "models/uuid_entry"

module UuidEntryable
  extend ActiveSupport::Concern

  included do
    has_one :uuid_entry, as: :entryable
  end
end
