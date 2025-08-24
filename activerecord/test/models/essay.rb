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

class EssayWithBelongsToInverseOf < Essay
  belongs_to :author, primary_key: :name, inverse_of: :essay_2_with_belongs_to_inverse_of
  belongs_to :writer, primary_key: :name, polymorphic: true, inverse_of: :essay_with_belongs_to_inverse_of
end

class EssayWithBelongsToScopedInverseOf < Essay
  belongs_to :author, -> { where("1=1") }, primary_key: :name, inverse_of: :essay_2_with_belongs_to_scoped_inverse_of
  belongs_to :writer, -> { where("1=1") }, primary_key: :name, polymorphic: true, inverse_of: :essay_with_belongs_to_scoped_inverse_of
end
