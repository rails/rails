# frozen_string_literal: true

class UuidEntry < ActiveRecord::Base
  delegated_type :entryable, types: %w[ UuidMessage UuidComment ], primary_key: :uuid, foreign_key: :entryable_uuid
end
