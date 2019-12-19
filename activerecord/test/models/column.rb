# frozen_string_literal: true

class Column < ActiveRecord::Base
  belongs_to :record
end
