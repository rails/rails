# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  belongs_to :subscriber, counter_cache: :books_count, optional: true
  belongs_to :book, -> { author_visibility_visible }, optional: true

  validates_presence_of :subscriber_id, :book_id
end
