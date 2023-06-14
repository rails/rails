# frozen_string_literal: true

class Choice < ActiveRecord::Base
  belongs_to :question
end

class ChoiceWithErrorRestriction < Choice
  has_many :answers,
           foreign_key: :choice_id,
           dependent: :restrict_with_error
end

class ChoiceWithExceptionRestriction < Choice
  has_many :answers,
           foreign_key: :choice_id,
           dependent: :restrict_with_exception
end
