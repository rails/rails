class Contact < ActiveRecord::Base
  establish_connection(:adapter => 'fake')

  connection.tables = ['contacts']
  connection.primary_keys = {
    'contacts' => 'id'
  }

  # mock out self.columns so no pesky db is needed for these tests
  def self.column(name, sql_type = nil, options = {})
    connection.merge_column('contacts', name, sql_type, options)
  end

  column :name,        :string
  column :age,         :integer
  column :avatar,      :binary
  column :created_at,  :datetime
  column :awesome,     :boolean
  column :preferences, :string

  serialize :preferences

  belongs_to :alternative, :class_name => 'Contact'
end
