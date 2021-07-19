# frozen_string_literal: true

class AddPeopleHobby < ActiveRecord::Migration::Current
  add_column :people, :hobby, :string
end
