# frozen_string_literal: true

class DaJoin < ActiveRecord::Base
  belongs_to :delete_association_parent
  belongs_to :da_has_many_through
end
