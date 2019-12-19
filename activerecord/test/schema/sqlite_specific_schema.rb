# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :defaults, force: true do |t|
    t.date :fixed_date, default: "2004-01-01"
    t.datetime :fixed_time, default: "2004-01-01 00:00:00"
    t.column :char1, "char(1)", default: "Y"
    t.string :char2, limit: 50, default: "a varchar field"
    t.text :char3, limit: 50, default: "a text field"
  end
end
