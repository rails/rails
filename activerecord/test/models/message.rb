# frozen_string_literal: true

class Message < ActiveRecord::Base
  has_one :entry, as: :entryable
end
