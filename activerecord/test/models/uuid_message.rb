# frozen_string_literal: true

require "models/uuid_entryable"

class UuidMessage < ActiveRecord::Base
  include UuidEntryable
end
