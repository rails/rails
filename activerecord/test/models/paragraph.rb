# frozen_string_literal: true

class Paragraph < ActiveRecord::Base
  belongs_to :book
end
