# frozen_string_literal: true

class Editorship < ActiveRecord::Base
  belongs_to :publication
  belongs_to :editor
end
