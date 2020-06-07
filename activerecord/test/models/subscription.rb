# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  belongs_to :subscriber, counter_cache: :books_count
  belongs_to :published_book
  belongs_to :book

  validates_presence_of :subscriber_id, :book_id
end
