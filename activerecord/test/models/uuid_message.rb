# frozen_string_literal: true

class UuidMessage < ActiveRecord::Base
  has_one :uuid_entry, as: :entryable
end
