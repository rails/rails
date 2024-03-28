# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  self.automatically_invert_plural_associations = true

  belongs_to :subscriber, counter_cache: :books_count
  belongs_to :book, -> { author_visibility_visible }

  validates_presence_of :subscriber_id, :book_id
end
