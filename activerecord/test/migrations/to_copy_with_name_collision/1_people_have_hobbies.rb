# frozen_string_literal: true

class PeopleHaveHobbies < ActiveRecord::Migration::Current
  def self.up
    add_column 'people', 'hobbies', :string
  end

  def self.down
    remove_column 'people', 'hobbies'
  end
end
