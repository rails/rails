# frozen_string_literal: true

class BookIdentifier < ActiveRecord::Base
  belongs_to :book
end
