# frozen_string_literal: true

module ContactFakeColumns
  def self.extended(base)
    base.class_eval do
      establish_connection(adapter: "fake")

      connection.data_sources = [table_name]
      connection.primary_keys = {
        table_name => "id"
      }

      column :id,             :integer
      column :name,           :string
      column :age,            :integer
      column :avatar,         :binary
      column :created_at,     :datetime
      column :awesome,        :boolean
      column :preferences,    :string
      column :alternative_id, :integer

      serialize :preferences

      belongs_to :alternative, class_name: "Contact"
    end
  end

  # mock out self.columns so no pesky db is needed for these tests
  def column(name, sql_type = nil, options = {})
    connection.merge_column(table_name, name, sql_type, options)
  end
end

class Contact < ActiveRecord::Base
  extend ContactFakeColumns
end

class ContactSti < ActiveRecord::Base
  extend ContactFakeColumns
  column :type, :string

  def type; "ContactSti" end
end
