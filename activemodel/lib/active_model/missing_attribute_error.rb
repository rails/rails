# frozen_string_literal: true

# :markup: markdown

module ActiveModel
  # Raised when an attribute is not defined.
  #
  # ```
  # class User < ActiveRecord::Base
  #   has_many :pets
  # end
  #
  # user = User.first
  # user.pets.select(:id).first.user_id
  # # => ActiveModel::MissingAttributeError: missing attribute 'user_id' for Pet
  # ```
  class MissingAttributeError < NoMethodError
  end
end
