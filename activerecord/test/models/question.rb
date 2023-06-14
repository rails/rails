# frozen_string_literal: true

class Question < ActiveRecord::Base
  has_many :choice_with_error_restrictions,
           dependent: :destroy
  has_many :choice_with_exception_restrictions,
           dependent: :destroy

  accepts_nested_attributes_for :choice_with_error_restrictions,
                                :choice_with_exception_restrictions,
                                allow_destroy: true
end
