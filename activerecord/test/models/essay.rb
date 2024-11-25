# frozen_string_literal: true

class Essay < ActiveRecord::Base
  belongs_to :author, primary_key: :name
  belongs_to :writer, primary_key: :name, polymorphic: true
  belongs_to :category, primary_key: :name
  has_one :owner, primary_key: :name
end

class EssaySpecial < Essay
end
class TypedEssay < Essay
end
