# frozen_string_literal: true

class Message < ActiveRecord::Base
  has_one  :entry, as: :entryable, touch: true
  has_many :recipients
end
