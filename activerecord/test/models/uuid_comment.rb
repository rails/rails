# frozen_string_literal: true

require "models/uuid_entryable"

class UuidComment < ActiveRecord::Base
  include UuidEntryable
end
