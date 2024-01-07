class CreateActionTextTables < ActiveRecord::Migration[6.0]
  def change
    # Use Active Record's configured type for primary and foreign keys
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :action_text_rich_texts, id: primary_key_type do |t|
      t.string     :name, null: false
      t.text       :body, size: :long
      t.references :record, null: false, polymorphic: true, index: false, type: foreign_key_type

      t.timestamps

      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end

  private
    def primary_and_foreign_key_types
      config = Rails.configuration.generators
      setting = config.options[config.orm][:primary_key_type]
      primary_key_type = setting || :primary_key
      foreign_key_type = setting || :bigint
      [ primary_key_type, foreign_key_type ]
    end
end
