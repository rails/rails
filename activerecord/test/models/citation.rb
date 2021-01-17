# frozen_string_literal: true

class Citation < ActiveRecord::Base
  belongs_to :book, foreign_key: :book1_id, inverse_of: :citations, touch: true
  belongs_to :reference_of, class_name: "Book", foreign_key: :book2_id
  has_many :citations
end
