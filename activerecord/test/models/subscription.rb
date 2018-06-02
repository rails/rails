# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  belongs_to :subscriber, counter_cache: :books_count
  belongs_to :book
end
