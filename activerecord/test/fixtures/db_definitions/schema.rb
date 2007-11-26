ActiveRecord::Schema.define do

  # adapter name is checked because we are under a transition of
  # moving the sql files under activerecord/test/fixtures/db_definitions
  # to this file, schema.rb.
  if adapter_name == "MySQL"
    
    # Please keep these create table statements in alphabetical order
    # unless the ordering matters.  In which case, define them below
    create_table :accounts, :force => true do |t|
      t.integer :firm_id
      t.integer :credit_limit
    end

    create_table :authors, :force => true do |t|
      t.string :name, :null => false
    end

    create_table :auto_id_tests, :force => true, :id => false do |t|
      t.primary_key :auto_id
      t.integer     :value
    end
    
    create_table :binaries, :force => true do |t|
      t.binary :data
    end

    create_table :booleantests, :force => true do |t|
      t.integer :value
    end

    create_table :categories, :force => true do |t|
      t.string :name, :null => false
      t.string :type
    end

    create_table :categories_posts, :force => true, :id => false do |t|
      t.integer :category_id, :null => false
      t.integer :post_id, :null => false
    end

    create_table :colnametests, :force => true do |t|
      t.integer :references, :null => false
    end
    
    create_table :comments, :force => true do |t|
      t.integer :post_id, :null => false
      t.text    :body, :null => false
      t.string  :type
    end

    create_table :companies, :force => true do |t|
      t.string  :type
      t.string  :ruby_type
      t.integer :firm_id
      t.string  :name
      t.integer :client_of
      t.integer :rating, :default => 1
    end
    
    create_table :computers, :force => true do |t|
      t.integer :developer, :null => false
      t.integer :extendedWarranty, :null => false
    end
    

    create_table :customers, :force => true do |t|
      t.string  :name
      t.integer :balance, :default => 0
      t.string  :address_street
      t.string  :address_city
      t.string  :address_country
      t.string  :gps_location
    end

    create_table :developers, :force => true do |t|
      t.string   :name
      t.integer  :salary, :default => 70000
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :developers_projects, :force => true, :id => false do |t|
      t.integer :developer_id, :null => false
      t.integer :project_id, :null => false
      t.date    :joined_on
      t.integer :access_level, :default => 1
    end

    create_table :entrants, :force => true do |t|
      t.string  :name, :null => false
      t.integer :course_id, :null => false
    end

    create_table :funny_jokes, :force => true do |t|
      t.string :name
    end
    
    create_table :keyboards, :force => true, :id  => false do |t|
      t.primary_key :key_number
      t.string      :name
    end
    
    create_table :legacy_things, :force => true do |t|
      t.integer :tps_report_number
      t.integer :version, :null => false, :default => 0
    end
    
    create_table :minimalistics, :force => true do |t|
    end
    
    create_table :mixed_case_monkeys, :force => true, :id => false do |t|
      t.primary_key :monkeyID
      t.integer     :fleaCount
    end
    
    create_table :mixins, :force => true do |t|
      t.integer  :parent_id
      t.integer  :pos
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :lft
      t.integer  :rgt
      t.integer  :root_id
      t.string   :type
    end
    
    create_table :movies, :force => true, :id => false do |t|
      t.primary_key :movieid
      t.string      :name
    end
    
    create_table :numeric_data, :force => true do |t|
      t.decimal :bank_balance, :precision => 10, :scale => 2
      t.decimal :big_bank_balance, :precision => 15, :scale => 2
      t.decimal :world_population, :precision => 10, :scale => 0
      t.decimal :my_house_population, :precision => 2, :scale => 0
      t.decimal :decimal_number_with_default, :precision => 3, :scale => 2, :default => 2.78
    end
    
    create_table :orders, :force => true do |t|
      t.string  :name
      t.integer :billing_customer_id
      t.integer :shipping_customer_id
    end

    create_table :people, :force => true do |t|
      t.string  :first_name, :null => false
      t.integer :lock_version, :null => false, :default => 0
    end
    
    create_table :posts, :force => true do |t|
      t.integer :author_id
      t.string  :title, :null => false
      t.text    :body, :null => false
      t.string  :type
    end

    create_table :projects, :force => true do |t|
      t.string :name
      t.string :type
    end
    
    create_table :readers, :force => true do |t|
      t.integer :post_id, :null => false
      t.integer :person_id, :null => false
    end
    
    create_table :subscribers, :force => true, :id => false do |t|
      t.string :nick, :null => false
      t.string :name
    end
    add_index :subscribers, :nick, :unique => true

    create_table :tasks, :force => true do |t|
      t.datetime :starting
      t.datetime :ending
    end

    create_table :topics, :force => true do |t|
      t.string   :title
      t.string   :author_name
      t.string   :author_email_address
      t.datetime :written_on
      t.time     :bonus_time
      t.date     :last_read
      t.text     :content
      t.boolean  :approved, :default => true
      t.integer  :replies_count, :default => 0
      t.integer  :parent_id
      t.string   :type
    end



    ### These tables are created last as the order is significant

    # fk_test_has_fk should be before fk_test_has_pk
    create_table :fk_test_has_fk, :force => true do |t|
      t.integer :fk_id, :null => false
    end

    create_table :fk_test_has_pk, :force => true do |t|
    end

    execute 'alter table fk_test_has_fk
               add FOREIGN KEY (`fk_id`) REFERENCES `fk_test_has_pk`(`id`)'


  end

  # For Firebird, set the sequence values 10000 when create_table is called;
  # this prevents primary key collisions between "normally" created records
  # and fixture-based (YAML) records.
  if adapter_name == "Firebird"
    def create_table(*args, &block)
      ActiveRecord::Base.connection.create_table(*args, &block)
      ActiveRecord::Base.connection.execute "SET GENERATOR #{args.first}_seq TO 10000"
    end
  end

  create_table :taggings, :force => true do |t|
    t.column :tag_id, :integer
    t.column :super_tag_id, :integer
    t.column :taggable_type, :string
    t.column :taggable_id, :integer
  end

  create_table :tags, :force => true do |t|
    t.column :name, :string
    t.column :taggings_count, :integer, :default => 0
  end

  create_table :categorizations, :force => true do |t|
    t.column :category_id, :integer
    t.column :post_id, :integer
    t.column :author_id, :integer
  end

  add_column :posts, :taggings_count, :integer, :default => 0
  add_column :authors, :author_address_id, :integer

  create_table :author_addresses, :force => true do |t|
    t.column :author_address_id, :integer
  end

  create_table :author_favorites, :force => true do |t|
    t.column :author_id, :integer
    t.column :favorite_author_id, :integer
  end

  create_table :vertices, :force => true do |t|
    t.column :label, :string
  end

  create_table :edges, :force => true do |t|
    t.column :source_id, :integer, :null => false
    t.column :sink_id,   :integer, :null => false
  end
  add_index :edges, [:source_id, :sink_id], :unique => true, :name => 'unique_edge_index'

  create_table :lock_without_defaults, :force => true do |t|
    t.column :lock_version, :integer
  end
  
  create_table :lock_without_defaults_cust, :force => true do |t|
    t.column :custom_lock_version, :integer
  end
  
  create_table :items, :force => true do |t|
    t.column :name, :integer
  end

  # For sqlite 3.1.0+, make a table with a autoincrement column
  if adapter_name == 'SQLite' and supports_autoincrement?
    create_table :table_with_autoincrement, :force => true do |t|
      t.column :name, :string
    end
  end
  
  # For sqlserver 2000+, ensure real columns can be used
  if adapter_name.starts_with?("SQLServer")
    create_table :table_with_real_columns, :force => true do |t|
      t.column :real_number, :real
    end
  end

  create_table :audit_logs, :force => true do |t|
    t.column :message, :string, :null=>false
    t.column :developer_id, :integer, :null=>false
  end

  create_table :books, :force => true do |t|
    t.column :name, :string
  end

  create_table :citations, :force => true do |t|
    t.column :book1_id, :integer
    t.column :book2_id, :integer
  end

  create_table :inept_wizards, :force => true do |t|
    t.column :name, :string, :null => false
    t.column :city, :string, :null => false
    t.column :type, :string
  end

  create_table :parrots, :force => true do |t|
    t.column :name, :string
    t.column :parrot_sti_class, :string
    t.column :killer_id, :integer
    t.column :created_at, :datetime
    t.column :created_on, :datetime
    t.column :updated_at, :datetime
    t.column :updated_on, :datetime
  end

  create_table :pirates, :force => true do |t|
    t.column :catchphrase, :string
    t.column :parrot_id, :integer
    t.column :created_on, :datetime
    t.column :updated_on, :datetime
  end

  create_table :parrots_pirates, :id => false, :force => true do |t|
    t.column :parrot_id, :integer
    t.column :pirate_id, :integer
  end

  create_table :treasures, :force => true do |t|
    t.column :name, :string
    t.column :looter_id, :integer
    t.column :looter_type, :string
  end

  create_table :parrots_treasures, :id => false, :force => true do |t|
    t.column :parrot_id, :integer
    t.column :treasure_id, :integer
  end

  create_table :mateys, :id => false, :force => true do |t|
    t.column :pirate_id, :integer
    t.column :target_id, :integer
    t.column :weight, :integer
  end

  create_table :ships, :force => true do |t|
    t.string :name
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
  end
end
