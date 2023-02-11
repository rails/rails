# frozen_string_literal: true

class Entry < ActiveRecord::Base
  delegated_type :entryable, types: %w[ Message Comment ]
  belongs_to :account, touch: true

  # alternate delegation for custom foreign_key/foreign_type
  delegated_type :thing, types: %w[ Post ],
    foreign_key: :entryable_id, foreign_type: :entryable_type
end
