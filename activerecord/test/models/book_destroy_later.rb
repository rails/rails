# frozen_string_literal: true

class BookDestroyLater < ActiveRecord::Base
  has_many :taggings, as: :taggable, class_name: "Tagging"
  has_many :tags, through: :taggings, dependent: :destroy_later
  has_many :essay_destroy_later, dependent: :destroy_later
  has_one :content, dependent: :destroy_later

  enum status: [:proposed, :written, :published]

  destroy_later after: 30.days, if: -> { status_previously_changed? && published? }, ensuring: :published?

  def published!
    super
    "do publish work..."
  end
end
