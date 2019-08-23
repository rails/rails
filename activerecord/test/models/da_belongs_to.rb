# frozen_string_literal: true

class DaBelongsTo < ActiveRecord::Base
  belongs_to :delete_association_parent, dependent: :background_delete
end
