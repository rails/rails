# frozen_string_literal: true

class BookDestroyAsync < ActiveRecord::Base
  self.table_name = "books"

  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, through: :taggings, dependent: :destroy_async
  has_many :essays, dependent: :destroy_async, class_name: "EssayDestroyAsync", foreign_key: "book_id"
  has_one :content, dependent: :destroy_async

  enum status: [:proposed, :written, :published]

  def published!
    super
    "do publish work..."
  end
end

class BookDestroyAsyncWithScopedTags < ActiveRecord::Base
  self.table_name = "books"

  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, -> { where name: "Der be rum" }, through: :taggings, dependent: :destroy_async
end
