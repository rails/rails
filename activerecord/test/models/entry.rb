# frozen_string_literal: true

class Entry < ActiveRecord::Base
  delegated_type :entryable, types: %w[ Message Comment ]
end
