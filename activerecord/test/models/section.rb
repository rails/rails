# frozen_string_literal: true

class Section < ActiveRecord::Base
  belongs_to :session, inverse_of: :sections, autosave: true
  belongs_to :seminar, inverse_of: :sections, autosave: true
end
