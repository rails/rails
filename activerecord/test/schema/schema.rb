ActiveRecord::Schema.define do
  def except(adapter_names_to_exclude)
    unless [adapter_names_to_exclude].flatten.include?(adapter_name)
      yield
    end
  end

  #put adapter specific setup here
  case adapter_name
    # For Firebird, set the sequence values 10000 when create_table is called;
    # this prevents primary key collisions between "normally" created records
    # and fixture-based (YAML) records.
  when "Firebird"
    def create_table(*args, &block)
      ActiveRecord::Base.connection.create_table(*args, &block)
      ActiveRecord::Base.connection.execute "SET GENERATOR #{args.first}_seq TO 10000"
    end
  end


  # ------------------------------------------------------------------- #
  #                                                                     #
  #   Please keep these create table statements in alphabetical order   #
  #   unless the ordering matters.  In which case, define them below.   #
  #                                                                     #
  # ------------------------------------------------------------------- #

  create_table :accounts, :force => true do |t|
    t.integer :firm_id
    t.string  :firm_name
    t.integer :credit_limit
  end

  create_table :admin_accounts, :force => true do |t|
    t.string :name
  end

  create_table :admin_users, :force => true do |t|
    t.string :name
    t.string :settings, :null => true, :limit => 1024
    # MySQL does not allow default values for blobs. Fake it out with a
    # big varchar below.
    t.string :preferences, :null => true, :default => '', :limit => 1024
    t.string :json_data, :null => true, :limit => 1024
    t.string :json_data_empty, :null => true, :default => "", :limit => 1024
    t.references :account
  end

  create_table :aircraft, :force => true do |t|
    t.string :name
  end

  create_table :audit_logs, :force => true do |t|
    t.column :message, :string, :null=>false
    t.column :developer_id, :integer, :null=>false
    t.integer :unvalidated_developer_id
  end

  create_table :authors, :force => true do |t|
    t.string :name, :null => false
    t.integer :author_address_id
    t.integer :author_address_extra_id
    t.string :organization_id
    t.string :owned_essay_id
  end

  create_table :author_addresses, :force => true do |t|
  end

  create_table :author_favorites, :force => true do |t|
    t.column :author_id, :integer
    t.column :favorite_author_id, :integer
  end

  create_table :auto_id_tests, :force => true, :id => false do |t|
    t.primary_key :auto_id
    t.integer     :value
  end

  create_table :binaries, :force => true do |t|
    t.string :name
    t.binary :data
    t.binary :short_data, :limit => 2048
  end

  create_table :birds, :force => true do |t|
    t.string :name
    t.string :color
    t.integer :pirate_id
  end

  create_table :books, :force => true do |t|
    t.integer :author_id
    t.column :name, :string
  end

  create_table :booleans, :force => true do |t|
    t.boolean :value
    t.boolean :has_fun, :null => false, :default => false
  end

  create_table :bulbs, :force => true do |t|
    t.integer :car_id
    t.string  :name
    t.boolean :frickinawesome
    t.string :color
  end

  create_table "CamelCase", :force => true do |t|
    t.string :name
  end

  create_table :cars, :force => true do |t|
    t.string  :name
    t.integer :engines_count
    t.integer :wheels_count
    t.column :lock_version, :integer, :null => false, :default => 0
    t.timestamps
  end

  create_table :categories, :force => true do |t|
    t.string :name, :null => false
    t.string :type
    t.integer :categorizations_count
  end

  create_table :categories_posts, :force => true, :id => false do |t|
    t.integer :category_id, :null => false
    t.integer :post_id, :null => false
  end

  create_table :categorizations, :force => true do |t|
    t.column :category_id, :integer
    t.string :named_category_name
    t.column :post_id, :integer
    t.column :author_id, :integer
    t.column :special, :boolean
  end

  create_table :citations, :force => true do |t|
    t.column :book1_id, :integer
    t.column :book2_id, :integer
  end

  create_table :clubs, :force => true do |t|
    t.string :name
    t.integer :category_id
  end

  create_table :collections, :force => true do |t|
    t.string :name
  end

  create_table :colnametests, :force => true do |t|
    t.integer :references, :null => false
  end

  create_table :comments, :force => true do |t|
    t.integer :post_id, :null => false
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      t.string  :body, :null => false, :limit => 4000
    else
      t.text    :body, :null => false
    end
    t.string  :type
    t.integer :taggings_count, :default => 0
    t.integer :children_count, :default => 0
    t.integer :parent_id
  end

  create_table :companies, :force => true do |t|
    t.string  :type
    t.integer :firm_id
    t.string  :firm_name
    t.string  :name
    t.integer :client_of
    t.integer :rating, :default => 1
    t.integer :account_id
    t.string :description, :default => ""
  end

  add_index :companies, [:firm_id, :type, :rating], :name => "company_index"
  add_index :companies, [:firm_id, :type], :name => "company_partial_index", :where => "rating > 10"

  create_table :vegetables, :force => true do |t|
    t.string :name
    t.integer :seller_id
    t.string :custom_type
  end

  create_table :computers, :force => true do |t|
    t.integer :developer, :null => false
    t.integer :extendedWarranty, :null => false
  end

  create_table :contracts, :force => true do |t|
    t.integer :developer_id
    t.integer :company_id
  end

  create_table :customers, :force => true do |t|
    t.string  :name
    t.integer :balance, :default => 0
    t.string  :address_street
    t.string  :address_city
    t.string  :address_country
    t.string  :gps_location
  end

  create_table :dashboards, :force => true, :id => false do |t|
    t.string :dashboard_id
    t.string :name
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

  create_table :dog_lovers, :force => true do |t|
    t.integer :trained_dogs_count, :default => 0
    t.integer :bred_dogs_count, :default => 0
  end

  create_table :dogs, :force => true do |t|
    t.integer :trainer_id
    t.integer :breeder_id
  end

  create_table :edges, :force => true, :id => false do |t|
    t.column :source_id, :integer, :null => false
    t.column :sink_id,   :integer, :null => false
  end
  add_index :edges, [:source_id, :sink_id], :unique => true, :name => 'unique_edge_index'

  create_table :engines, :force => true do |t|
    t.integer :car_id
  end

  create_table :entrants, :force => true do |t|
    t.string  :name, :null => false
    t.integer :course_id, :null => false
  end

  create_table :essays, :force => true do |t|
    t.string :name
    t.string :writer_id
    t.string :writer_type
    t.string :category_id
    t.string :author_id
  end

  create_table :events, :force => true do |t|
    t.string :title, :limit => 5
  end

  create_table :eyes, :force => true do |t|
  end

  create_table :funny_jokes, :force => true do |t|
    t.string :name
  end

  create_table :cold_jokes, :force => true do |t|
    t.string :name
  end

  create_table :friendships, :force => true do |t|
    t.integer :friend_id
    t.integer :person_id
  end

  create_table :goofy_string_id, :force => true, :id => false do |t|
    t.string :id, :null => false
    t.string :info
  end

  create_table :having, :force => true do |t|
    t.string :where
  end

  create_table :guids, :force => true do |t|
    t.column :key, :string
  end

  create_table :inept_wizards, :force => true do |t|
    t.column :name, :string, :null => false
    t.column :city, :string, :null => false
    t.column :type, :string
  end

  create_table :integer_limits, :force => true do |t|
    t.integer :"c_int_without_limit"
    (1..8).each do |i|
      t.integer :"c_int_#{i}", :limit => i
    end
  end

  create_table :invoices, :force => true do |t|
    t.integer :balance
    t.datetime :updated_at
  end

  create_table :iris, :force => true do |t|
    t.references :eye
    t.string     :color
  end

  create_table :items, :force => true do |t|
    t.column :name, :string
  end

  create_table :jobs, :force => true do |t|
    t.integer :ideal_reference_id
  end

  create_table :keyboards, :force => true, :id  => false do |t|
    t.primary_key :key_number
    t.string      :name
  end

  create_table :legacy_things, :force => true do |t|
    t.integer :tps_report_number
    t.integer :version, :null => false, :default => 0
  end

  create_table :lessons, :force => true do |t|
    t.string :name
  end

  create_table :lessons_students, :id => false, :force => true do |t|
    t.references :lesson
    t.references :student
  end

  create_table :lint_models, :force => true

  create_table :line_items, :force => true do |t|
    t.integer :invoice_id
    t.integer :amount
  end

  create_table :lock_without_defaults, :force => true do |t|
    t.column :lock_version, :integer
  end

  create_table :lock_without_defaults_cust, :force => true do |t|
    t.column :custom_lock_version, :integer
  end

  create_table :mateys, :id => false, :force => true do |t|
    t.column :pirate_id, :integer
    t.column :target_id, :integer
    t.column :weight, :integer
  end

  create_table :members, :force => true do |t|
    t.string :name
    t.integer :member_type_id
  end

  create_table :member_details, :force => true do |t|
    t.integer :member_id
    t.integer :organization_id
    t.string :extra_data
  end

  create_table :member_friends, :force => true, :id => false do |t|
    t.integer :member_id
    t.integer :friend_id
  end

  create_table :memberships, :force => true do |t|
    t.datetime :joined_on
    t.integer :club_id, :member_id
    t.boolean :favourite, :default => false
    t.string :type
  end

  create_table :member_types, :force => true do |t|
    t.string :name
  end

  create_table :minivans, :force => true, :id => false do |t|
    t.string :minivan_id
    t.string :name
    t.string :speedometer_id
    t.string :color
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
    t.float   :temperature
    # Oracle/SQLServer supports precision up to 38
    if current_adapter?(:OracleAdapter,:SQLServerAdapter)
      t.decimal :atoms_in_universe, :precision => 38, :scale => 0
    else
      t.decimal :atoms_in_universe, :precision => 55, :scale => 0
    end
  end

  create_table :orders, :force => true do |t|
    t.string  :name
    t.integer :billing_customer_id
    t.integer :shipping_customer_id
  end

  create_table :organizations, :force => true do |t|
    t.string :name
  end

  create_table :owners, :primary_key => :owner_id ,:force => true do |t|
    t.string :name
    t.column :updated_at, :datetime
    t.column :happy_at,   :datetime
    t.string :essay_id
  end

  create_table :paint_colors, :force => true do |t|
    t.integer :non_poly_one_id
  end

  create_table :paint_textures, :force => true do |t|
    t.integer :non_poly_two_id
  end

  create_table :parrots, :force => true do |t|
    t.column :name, :string
    t.column :color, :string
    t.column :parrot_sti_class, :string
    t.column :killer_id, :integer
    t.column :created_at, :datetime
    t.column :created_on, :datetime
    t.column :updated_at, :datetime
    t.column :updated_on, :datetime
  end

  create_table :parrots_pirates, :id => false, :force => true do |t|
    t.column :parrot_id, :integer
    t.column :pirate_id, :integer
  end

  create_table :parrots_treasures, :id => false, :force => true do |t|
    t.column :parrot_id, :integer
    t.column :treasure_id, :integer
  end

  create_table :people, :force => true do |t|
    t.string     :first_name, :null => false
    t.references :primary_contact
    t.string     :gender, :limit => 1
    t.references :number1_fan
    t.integer    :lock_version, :null => false, :default => 0
    t.string     :comments
    t.integer    :followers_count, :default => 0
    t.references :best_friend
    t.references :best_friend_of
    t.integer    :insures, null: false, default: 0
    t.timestamps
  end

  create_table :peoples_treasures, :id => false, :force => true do |t|
    t.column :rich_person_id, :integer
    t.column :treasure_id, :integer
  end

  create_table :pets, :primary_key => :pet_id ,:force => true do |t|
    t.string :name
    t.integer :owner_id, :integer
    t.timestamps
  end

  create_table :pirates, :force => true do |t|
    t.column :catchphrase, :string
    t.column :parrot_id, :integer
    t.integer :non_validated_parrot_id
    t.column :created_on, :datetime
    t.column :updated_on, :datetime
  end

  create_table :posts, :force => true do |t|
    t.integer :author_id
    t.string  :title, :null => false
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      t.string  :body, :null => false, :limit => 4000
    else
      t.text    :body, :null => false
    end
    t.string  :type
    t.integer :comments_count, :default => 0
    t.integer :taggings_count, :default => 0
    t.integer :taggings_with_delete_all_count, :default => 0
    t.integer :taggings_with_destroy_count, :default => 0
    t.integer :tags_count, :default => 0
    t.integer :tags_with_destroy_count, :default => 0
    t.integer :tags_with_nullify_count, :default => 0
  end

  create_table :price_estimates, :force => true do |t|
    t.string :estimate_of_type
    t.integer :estimate_of_id
    t.integer :price
  end

  create_table :products, :force => true do |t|
    t.references :collection
    t.string     :name
  end

  create_table :projects, :force => true do |t|
    t.string :name
    t.string :type
  end

  create_table :randomly_named_table, :force => true do |t|
    t.string  :some_attribute
    t.integer :another_attribute
  end

  create_table :ratings, :force => true do |t|
    t.integer :comment_id
    t.integer :value
  end

  create_table :readers, :force => true do |t|
    t.integer :post_id, :null => false
    t.integer :person_id, :null => false
    t.boolean :skimmer, :default => false
    t.integer :first_post_id
  end

  create_table :references, :force => true do |t|
    t.integer :person_id
    t.integer :job_id
    t.boolean :favourite
    t.integer :lock_version, :default => 0
  end

  create_table :shape_expressions, :force => true do |t|
    t.string  :paint_type
    t.integer :paint_id
    t.string  :shape_type
    t.integer :shape_id
  end

  create_table :ships, :force => true do |t|
    t.string :name
    t.integer :pirate_id
    t.integer :update_only_pirate_id
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
  end

  create_table :ship_parts, :force => true do |t|
    t.string :name
    t.integer :ship_id
  end

  create_table :speedometers, :force => true, :id => false do |t|
    t.string :speedometer_id
    t.string :name
    t.string :dashboard_id
  end

  create_table :sponsors, :force => true do |t|
    t.integer :club_id
    t.integer :sponsorable_id
    t.string :sponsorable_type
  end

  create_table :string_key_objects, :id => false, :primary_key => :id, :force => true do |t|
    t.string     :id
    t.string     :name
    t.integer    :lock_version, :null => false, :default => 0
  end

  create_table :students, :force => true do |t|
    t.string :name
  end

  create_table :subscribers, :force => true, :id => false do |t|
    t.string :nick, :null => false
    t.string :name
    t.column :books_count, :integer, :null => false, :default => 0
  end
  add_index :subscribers, :nick, :unique => true

  create_table :subscriptions, :force => true do |t|
    t.string :subscriber_id
    t.integer :book_id
  end

  create_table :tags, :force => true do |t|
    t.column :name, :string
    t.column :taggings_count, :integer, :default => 0
  end

  create_table :taggings, :force => true do |t|
    t.column :tag_id, :integer
    t.column :super_tag_id, :integer
    t.column :taggable_type, :string
    t.column :taggable_id, :integer
    t.string :comment
  end

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
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      t.string   :content, :limit => 4000
      t.string   :important, :limit => 4000
    else
      t.text     :content
      t.text     :important
    end
    t.boolean  :approved, :default => true
    t.integer  :replies_count, :default => 0
    t.integer  :parent_id
    t.string   :parent_title
    t.string   :type
    t.string   :group
    t.timestamps
  end

  create_table :toys, :primary_key => :toy_id ,:force => true do |t|
    t.string :name
    t.integer :pet_id, :integer
    t.timestamps
  end

  create_table :traffic_lights, :force => true do |t|
    t.string   :location
    t.string   :state
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :treasures, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :looter_id, :integer
    t.column :looter_type, :string
  end

  create_table :tyres, :force => true do |t|
    t.integer :car_id
  end

  create_table :variants, :force => true do |t|
    t.references :product
    t.string     :name
  end

  create_table :vertices, :force => true do |t|
    t.column :label, :string
  end

  create_table 'warehouse-things', :force => true do |t|
    t.integer :value
  end

  [:circles, :squares, :triangles, :non_poly_ones, :non_poly_twos].each do |t|
    create_table(t, :force => true) { }
  end

  # NOTE - the following 4 tables are used by models that have :inverse_of options on the associations
  create_table :men, :force => true do |t|
    t.string  :name
  end

  create_table :faces, :force => true do |t|
    t.string  :description
    t.integer :man_id
    t.integer :polymorphic_man_id
    t.string  :polymorphic_man_type
    t.integer :horrible_polymorphic_man_id
    t.string  :horrible_polymorphic_man_type
  end

  create_table :interests, :force => true do |t|
    t.string :topic
    t.integer :man_id
    t.integer :polymorphic_man_id
    t.string :polymorphic_man_type
    t.integer :zine_id
  end

  create_table :wheels, :force => true do |t|
    t.references :wheelable, :polymorphic => true
  end

  create_table :zines, :force => true do |t|
    t.string :title
  end

  create_table :countries, :force => true, :id => false, :primary_key => 'country_id' do |t|
    t.string :country_id
    t.string :name
  end
  create_table :treaties, :force => true, :id => false, :primary_key => 'treaty_id' do |t|
    t.string :treaty_id
    t.string :name
  end
  create_table :countries_treaties, :force => true, :id => false do |t|
    t.string :country_id, :null => false
    t.string :treaty_id, :null => false
  end

  create_table :liquid, :force => true do |t|
    t.string :name
  end
  create_table :molecules, :force => true do |t|
    t.integer :liquid_id
    t.string :name
  end
  create_table :electrons, :force => true do |t|
    t.integer :molecule_id
    t.string :name
  end
  create_table :weirds, :force => true do |t|
    t.string 'a$b'
    t.string 'from'
  end

  except 'SQLite' do
    # fk_test_has_fk should be before fk_test_has_pk
    create_table :fk_test_has_fk, :force => true do |t|
      t.integer :fk_id, :null => false
    end

    create_table :fk_test_has_pk, :force => true do |t|
    end

    execute "ALTER TABLE fk_test_has_fk ADD CONSTRAINT fk_name FOREIGN KEY (#{quote_column_name 'fk_id'}) REFERENCES #{quote_table_name 'fk_test_has_pk'} (#{quote_column_name 'id'})"

    execute "ALTER TABLE lessons_students ADD CONSTRAINT student_id_fk FOREIGN KEY (#{quote_column_name 'student_id'}) REFERENCES #{quote_table_name 'students'} (#{quote_column_name 'id'})"
  end
end

Course.connection.create_table :courses, :force => true do |t|
  t.column :name, :string, :null => false
  t.column :college_id, :integer
end

College.connection.create_table :colleges, :force => true do |t|
  t.column :name, :string, :null => false
end
