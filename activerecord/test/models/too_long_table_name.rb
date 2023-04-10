# frozen_string_literal: true

class TooLongTableName < ActiveRecord::Base
  self.table_name = "toooooooooooooooooooooooooooooooooo_long_table_names"
end
