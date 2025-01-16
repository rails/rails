# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :datetime_defaults, force: true do |t|
    t.datetime :modified_datetime, precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime :precise_datetime, default: -> { "CURRENT_TIMESTAMP(6)" }
    t.datetime :updated_datetime, default: -> { "CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)" }
  end

  create_table :timestamp_defaults, force: true do |t|
    t.timestamp :nullable_timestamp
    t.timestamp :modified_timestamp, precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.timestamp :precise_timestamp, precision: 6, default: -> { "CURRENT_TIMESTAMP(6)" }
    t.timestamp :updated_timestamp, precision: 6, default: -> { "CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)" }
  end

  create_table :defaults, force: true do |t|
    t.date :fixed_date, default: "2004-01-01"
    t.datetime :fixed_time, default: "2004-01-01 00:00:00"
    t.column :char1, "char(1)", default: "Y"
    t.string :char2, limit: 50, default: "a varchar field"
    if ActiveRecord::TestCase.supports_default_expression?
      t.binary :uuid, limit: 36, default: -> { "(uuid())" }
      t.string :char2_concatenated, default: -> { "(concat(`char2`, '-'))" }
    end
  end

  create_table :binary_fields, force: true do |t|
    t.binary :var_binary, limit: 255
    t.binary :var_binary_large, limit: 4095

    t.tinyblob   :tiny_blob
    t.blob       :normal_blob
    t.mediumblob :medium_blob
    t.longblob   :long_blob
    t.tinytext   :tiny_text
    t.text       :normal_text
    t.mediumtext :medium_text
    t.longtext   :long_text

    t.binary :tiny_blob_2, size: :tiny
    t.binary :medium_blob_2, size: :medium
    t.binary :long_blob_2, size: :long
    t.text :tiny_text_2, size: :tiny
    t.text :medium_text_2, size: :medium
    t.text :long_text_2, size: :long

    t.index :var_binary
  end

  create_table :key_tests, force: true, options: "CHARSET=utf8 ENGINE=MyISAM" do |t|
    t.string :awesome
    t.string :pizza
    t.string :snacks
    t.index :awesome, type: :fulltext, name: "index_key_tests_on_awesome"
    t.index :pizza, using: :btree, name: "index_key_tests_on_pizza"
    t.index :snacks, name: "index_key_tests_on_snack"
  end

  create_table :collation_tests, id: false, force: true do |t|
    t.string :string_cs_column, limit: 1, collation: "utf8mb4_bin"
    t.string :string_ci_column, limit: 1, collation: "utf8mb4_general_ci"
    t.binary :binary_column,    limit: 1
  end

  execute "DROP PROCEDURE IF EXISTS ten"

  execute <<~SQL
    CREATE PROCEDURE ten() SQL SECURITY INVOKER
    BEGIN
      SELECT 10;
    END
  SQL

  execute "DROP PROCEDURE IF EXISTS topics"

  execute <<~SQL
    CREATE PROCEDURE topics(IN num INT) SQL SECURITY INVOKER
    BEGIN
      SELECT * FROM topics LIMIT num;
    END
  SQL

  if supports_insert_returning?
    create_table :pk_autopopulated_by_a_trigger_records, force: true, id: false do |t|
      t.integer :id, null: false
    end

    execute <<~SQL
      CREATE TRIGGER before_insert_trigger
      BEFORE INSERT ON pk_autopopulated_by_a_trigger_records
      FOR EACH ROW
      SET NEW.id = (SELECT COALESCE(MAX(id), 0) + 1 FROM pk_autopopulated_by_a_trigger_records);
    SQL
  end
end
