# frozen_string_literal: true

class Answer < ActiveRecord::Base
  belongs_to :choice
end
