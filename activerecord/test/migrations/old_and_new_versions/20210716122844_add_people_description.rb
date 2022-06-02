# frozen_string_literal: true

class AddPeopleDescription < ActiveRecord::Migration::Current
  add_column :people, :description, :string
end
