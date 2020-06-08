# frozen_string_literal: true

class Book < ActiveRecord::Base
  belongs_to :author

  has_many :citations, foreign_key: "book1_id"
  has_many :references, -> { distinct }, through: :citations, source: :reference_of

  has_many :subscriptions
  has_many :subscribers, through: :subscriptions

  enum status: [:proposed, :written, :published]
  enum last_read: { unread: 0, reading: 2, read: 3, forgotten: nil }
  enum nullable_status: [:single, :married]
  enum language: [:english, :spanish, :french], _prefix: :in
  enum author_visibility: [:visible, :invisible], _prefix: true
  enum illustrator_visibility: [:visible, :invisible], _prefix: true
  enum font_size: [:small, :medium, :large], _prefix: :with, _suffix: true
  enum difficulty: [:easy, :medium, :hard], _suffix: :to_read
  enum cover: { hard: "hard", soft: "soft" }
  enum boolean_status: { enabled: true, disabled: false }

  def published!
    super
    "do publish work..."
  end
end

class PublishedBook < ActiveRecord::Base
  self.table_name = "books"

  validates_uniqueness_of :isbn
end
