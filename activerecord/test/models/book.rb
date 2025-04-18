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

  enum :status, [:proposed, :written, :published]
  enum :last_read, { unread: 0, reading: 2, read: 3, forgotten: nil }
  enum :nullable_status, [:single, :married]
  enum :language, [:english, :spanish, :french], prefix: :in
  enum :author_visibility, [:visible, :invisible], prefix: true
  enum :illustrator_visibility, [:visible, :invisible], prefix: true
  enum :font_size, [:small, :medium, :large], prefix: :with, suffix: true
  enum :difficulty, [:easy, :medium, :hard], suffix: :to_read
  enum :cover, { hard: "hard", soft: "soft" }
  enum :boolean_status, { enabled: true, disabled: false }
  enum :symbol_status, { proposed: :proposed, published: :published }, prefix: true

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
