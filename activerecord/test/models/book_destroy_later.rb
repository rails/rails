# frozen_string_literal: true

class BookDestroyLater < ActiveRecord::Base
  self.table_name = "books"
  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, through: :taggings, dependent: :destroy_later
  has_many :essays, dependent: :destroy_later, class_name: "EssayDestroyLater", foreign_key: "book_id"
  has_one :content, dependent: :destroy_later

  enum status: [:proposed, :written, :published]

  destroy_later after: 30.days, if: -> { status_previously_changed? && published? }, ensuring: :published?

  def published!
    super
    "do publish work..."
  end
end

class BookDestroyLaterWithScopedTags < ActiveRecord::Base
  self.table_name = "books"

  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, -> { where name: "Der be rum" }, through: :taggings, dependent: :destroy_later
end
