# frozen_string_literal: true

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :title, :string
  attribute :body, :string
end
