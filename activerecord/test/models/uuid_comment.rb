# frozen_string_literal: true

class UuidComment < ActiveRecord::Base
  has_one :uuid_entry, as: :entryable
end
