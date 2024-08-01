# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :defaults, force: true do |t|
      t.integer :random_number, default: -> { "ABS(RANDOM())" }
      t.string :ruby_on_rails, default: -> { "('Ruby ' || 'on ' || 'Rails')" }
      t.date :modified_date, default: -> { "CURRENT_DATE" }
      t.date :modified_date_function, default: -> { "DATE('now')" }
      t.date :fixed_date, default: "2004-01-01"
      t.datetime :modified_time, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :modified_time_without_precision, precision: nil, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :modified_time_with_precision_0, precision: 0, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :modified_time_function, default: -> { "DATETIME('now')" }
      t.datetime :fixed_time, default: "2004-01-01 00:00:00.000000-00"
      t.column :char1, "char(1)", default: "Y"
      t.string :char2, limit: 50, default: "a varchar field"
      t.text :char3, default: "a text field"
      t.text :multiline_default, default: "--- []

"
    end
end
