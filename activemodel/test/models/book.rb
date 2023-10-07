# frozen_string_literal: true

class Book
  include ActiveModel::Validations

  attr_accessor :author, :title
end
