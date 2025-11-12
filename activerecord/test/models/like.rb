# frozen_string_literal: true

class Like < ActiveRecord::Base
  has_and_belongs_to_many :published_books, autosave: true
end
