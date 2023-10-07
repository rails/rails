# frozen_string_literal: true

class Author
  include ActiveModel::Validations

  attr_accessor :books, :name
end
