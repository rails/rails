class Book < ActiveRecord::Base
  has_many :authors

  has_many :citations, :foreign_key => 'book1_id'
  has_many :references, -> { distinct }, through: :citations, source: :reference_of

  has_many :subscriptions
  has_many :subscribers, through: :subscriptions

  enum status: [:proposed, :written, :published]
  enum read_status: {unread: 0, reading: 2, read: 3}
  enum nullable_status: [:single, :married]

  enum(font_size: [:small, :medium, :large], enum_prefix: 'available_in', enum_postfix: 'font')
  enum(topic: [:ruby, :rails], enum_prefix: 'about')
  enum(author_visibility: [:visible, :invisible], enum_postfix: 'for_author')
  enum(illustrator_visibility: [:visible, :invisible], enum_postfix: 'for_illustrator')

  def published!
    super
    "do publish work..."
  end
end
