# frozen_string_literal: true

class Mascot < ActiveRecord::Base
  belongs_to :company, optional: false
end
