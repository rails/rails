# frozen_string_literal: true

class CreateActionPackPasskeysPasskeys < ActiveRecord::Migration[8.2]
  def change
    create_table :action_pack_passkeys_passkeys do |t|
      t.belongs_to :holder, polymorphic: true, null: false
      t.string :credential_id, null: false
      t.binary :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :name
      t.text :transports
      t.string :relying_party_id
      t.string :aaguid, limit: 36
      t.boolean :backed_up

      t.timestamps

      t.index :credential_id, unique: true
    end
  end
end
