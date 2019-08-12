# frozen_string_literal: true

class EssayDestroyLater < ActiveRecord::Base
  belongs_to :book_destroy_later, dependent: :destroy_later
end
