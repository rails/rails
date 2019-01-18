class CreateActionMailboxTables < ActiveRecord::Migration[6.0]
  def change
    create_table :action_mailbox_inbound_emails do |t|
      t.integer :status, default: 0, null: false
      t.string  :message_id, null: false
      t.string  :message_checksum, null: false

      if supports_datetime_with_precision?
        t.timestamps precision: 6
      else
        t.timestamps
      end

      t.index [ :message_id, :message_checksum ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end
end
