# frozen_string_literal: true

class AbstractDoubloon < ActiveRecord::Base
  # This has functionality that might be shared by multiple classes.

  self.abstract_class = true
  belongs_to :pirate
end

class Doubloon < AbstractDoubloon
  # This uses an abstract class that defines attributes and associations.

  self.table_name = "doubloons"
end
