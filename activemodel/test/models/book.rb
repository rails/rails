# frozen_string_literal: true

class Book
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include ActiveModel::Enum

  attribute :status, :integer
  attribute :last_read, :integer
  attribute :nullable_status, :integer
  attribute :language, :integer
  attribute :author_visibility, :integer
  attribute :illustrator_visibility, :integer
  attribute :font_size, :integer
  attribute :difficulty, :integer
  attribute :cover, :string
  attribute :boolean_status, :boolean

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
