# frozen_string_literal: true

class Book < ActiveRecord::Base
  belongs_to :author
  belongs_to :format_record, polymorphic: true

  has_many :citations, inverse_of: :book
  has_many :references, -> { distinct }, through: :citations, source: :reference_of

  has_many :subscriptions
  has_many :subscribers, through: :subscriptions

  has_one :essay

  alias_attribute :title, :name

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
  enum explicit_negative_status: [:unassigned, :not_started, :started, :completed], _negative_scopes: false

  def published!
    super
    "do publish work..."
  end
end

class PublishedBook < ActiveRecord::Base
  self.table_name = "books"

  enum :cover, { hard: "0", soft: "1" }, default: :hard

  validates_uniqueness_of :isbn
end
