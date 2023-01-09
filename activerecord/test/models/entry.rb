# frozen_string_literal: true

class Entry < ActiveRecord::Base
  delegated_type :entryable, types: %w[ Message Comment ]
  belongs_to :account, touch: true
end
