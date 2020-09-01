# frozen_string_literal: true

class BookDestroyLater < ActiveRecord::Base
  self.table_name = "books"
  has_many :taggings, as: :taggable, class_name: "Tagging"

  enum status: [:proposed, :written, :published]

  destroy_later after: 30.days, if: -> { status_previously_changed? && published? }, ensuring: :published?

  def published!
    super
    "do publish work..."
  end
end
