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

  create_table :accounts, :force => true do
    integer :firm_id
    string  :firm_name
    integer :credit_limit
  end

  create_table :admin_accounts, :force => true do
    string :name
  end

  create_table :admin_users, :force => true do
    string :name
    text :settings
    references :account
  end

  create_table :aircraft, :force => true do
    string :name
  end

  create_table :audit_logs, :force => true do
    string :message, :null => false
    integer :developer_id, :null => false
    integer :unvalidated_developer_id
  end

  create_table :authors, :force => true do
    string :name, :null => false
    integer :author_address_id
    integer :author_address_extra_id
    string :organization_id
    string :owned_essay_id
  end

  create_table :author_addresses, :force => true

  create_table :author_favorites, :force => true do
    integer :author_id
    integer :favorite_author_id
  end

  create_table :auto_id_tests, :force => true, :id => false do
    primary_key :auto_id
    integer     :value
  end

  create_table :binaries, :force => true do
    string :name
    binary :data
  end

  create_table :birds, :force => true do
    string :name
    string :color
    integer :pirate_id
  end

  create_table :books, :force => true do
    integer :author_id
    string :name
  end

  create_table :booleans, :force => true do
    boolean :value
  end

  create_table :bulbs, :force => true do
    integer :car_id
    string  :name
    boolean :frickinawesome
    string :color
  end

  create_table "CamelCase", :force => true do
    string :name
  end

  create_table :cars, :force => true do
    string  :name
    integer :engines_count
    integer :wheels_count
  end

  create_table :categories, :force => true do
    string :name, :null => false
    string :type
    integer :categorizations_count
  end

  create_table :categories_posts, :force => true, :id => false do
    integer :category_id, :null => false
    integer :post_id, :null => false
  end

  create_table :categorizations, :force => true do
    integer :category_id
    string :named_category_name
    integer :post_id
    integer :author_id
    boolean :special
  end

  create_table :citations, :force => true do
    integer :book1_id
    integer :book2_id
  end

  create_table :clubs, :force => true do
    string :name
    integer :category_id
  end

  create_table :collections, :force => true do
    string :name
  end

  create_table :colnametests, :force => true do
    integer :references, :null => false
  end

  create_table :comments, :force => true do
    integer :post_id, :null => false
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      string  :body, :null => false, :limit => 4000
    else
      text    :body, :null => false
    end
    string  :type
    integer :taggings_count, :default => 0
    integer :children_count, :default => 0
    integer :parent_id
  end

  create_table :companies, :force => true do
    string  :type
    string  :ruby_type
    integer :firm_id
    string  :firm_name
    string  :name
    integer :client_of
    integer :rating, :default => 1
    integer :account_id
  end

  add_index :companies, [:firm_id, :type, :rating, :ruby_type], :name => "company_index"

  create_table :computers, :force => true do
    integer :developer, :null => false
    integer :extendedWarranty, :null => false
  end

  create_table :contracts, :force => true do
    integer :developer_id
    integer :company_id
  end

  create_table :customers, :force => true do
    string  :name
    integer :balance, :default => 0
    string  :address_street
    string  :address_city
    string  :address_country
    string  :gps_location
  end

  create_table :dashboards, :force => true, :id => false do
    string :dashboard_id
    string :name
  end

  create_table :developers, :force => true do
    string   :name
    integer  :salary, :default => 70000
    datetime :created_at
    datetime :updated_at
  end

  create_table :developers_projects, :force => true, :id => false do
    integer :developer_id, :null => false
    integer :project_id, :null => false
    date    :joined_on
    integer :access_level, :default => 1
  end

  create_table :edges, :force => true, :id => false do
    integer :source_id, :null => false
    integer :sink_id, :null => false
  end
  add_index :edges, [:source_id, :sink_id], :unique => true, :name => 'unique_edge_index'

  create_table :engines, :force => true do
    integer :car_id
  end

  create_table :entrants, :force => true do
    string  :name, :null => false
    integer :course_id, :null => false
  end

  create_table :essays, :force => true do
    string :name
    string :writer_id
    string :writer_type
    string :category_id
    string :author_id
  end

  create_table :events, :force => true do
    string :title, :limit => 5
  end

  create_table :eyes, :force => true

  create_table :funny_jokes, :force => true do
    string :name
  end

  create_table :cold_jokes, :force => true do
    string :name
  end

  create_table :goofy_string_id, :force => true, :id => false do
    string :id, :null => false
    string :info
  end

  create_table :guids, :force => true do
    string :key
  end

  create_table :inept_wizards, :force => true do
    string :name, :null => false
    string :city, :null => false
    string :type
  end

  create_table :integer_limits, :force => true do
    integer :"c_int_without_limit"
    (1..8).each do |i|
      integer :"c_int_#{i}", :limit => i
    end
  end

  create_table :invoices, :force => true do
    integer :balance
    datetime :updated_at
  end

  create_table :iris, :force => true do
    references :eye
    string     :color
  end

  create_table :items, :force => true do
    string :name
  end

  create_table :jobs, :force => true do
    integer :ideal_reference_id
  end

  create_table :keyboards, :force => true, :id  => false do
    primary_key :key_number
    string      :name
  end

  create_table :legacy_things, :force => true do
    integer :tps_report_number
    integer :version, :null => false, :default => 0
  end

  create_table :lessons, :force => true do
    string :name
  end

  create_table :lessons_students, :id => false, :force => true do
    references :lesson
    references :student
  end

  create_table :lint_models, :force => true

  create_table :line_items, :force => true do
    integer :invoice_id
    integer :amount
  end

  create_table :lock_without_defaults, :force => true do
    integer :lock_version
  end

  create_table :lock_without_defaults_cust, :force => true do
    integer :custom_lock_version
  end

  create_table :mateys, :id => false, :force => true do
    integer :pirate_id
    integer :target_id
    integer :weight
  end

  create_table :members, :force => true do
    string :name
    integer :member_type_id
  end

  create_table :member_details, :force => true do
    integer :member_id
    integer :organization_id
    string :extra_data
  end

  create_table :memberships, :force => true do
    datetime :joined_on
    integer :club_id, :member_id
    boolean :favourite, :default => false
    string :type
  end

  create_table :member_types, :force => true do
    string :name
  end

  create_table :minivans, :force => true, :id => false do
    string :minivan_id
    string :name
    string :speedometer_id
    string :color
  end

  create_table :minimalistics, :force => true

  create_table :mixed_case_monkeys, :force => true, :id => false do
    primary_key :monkeyID
    integer     :fleaCount
  end

  create_table :mixins, :force => true do
    integer  :parent_id
    integer  :pos
    datetime :created_at
    datetime :updated_at
    integer  :lft
    integer  :rgt
    integer  :root_id
    string   :type
  end

  create_table :movies, :force => true, :id => false do
    primary_key :movieid
    string      :name
  end

  create_table :numeric_data, :force => true do
    decimal :bank_balance, :precision => 10, :scale => 2
    decimal :big_bank_balance, :precision => 15, :scale => 2
    decimal :world_population, :precision => 10, :scale => 0
    decimal :my_house_population, :precision => 2, :scale => 0
    decimal :decimal_number_with_default, :precision => 3, :scale => 2, :default => 2.78
    float   :temperature
    # Oracle/SQLServer supports precision up to 38
    if current_adapter?(:OracleAdapter,:SQLServerAdapter)
      decimal :atoms_in_universe, :precision => 38, :scale => 0
    else
      decimal :atoms_in_universe, :precision => 55, :scale => 0
    end
  end

  create_table :orders, :force => true do
    string  :name
    integer :billing_customer_id
    integer :shipping_customer_id
  end

  create_table :organizations, :force => true do
    string :name
  end

  create_table :owners, :primary_key => :owner_id, :force => true do
    string :name
    datetime :updated_at
    datetime :happy_at
    string :essay_id
  end

  create_table :paint_colors, :force => true do
    integer :non_poly_one_id
  end

  create_table :paint_textures, :force => true do
    integer :non_poly_two_id
  end

  create_table :parrots, :force => true do
    string :name
    string :parrot_sti_class
    integer :killer_id
    datetime :created_at
    datetime :created_on
    datetime :updated_at
    datetime :updated_on
  end

  create_table :parrots_pirates, :id => false, :force => true do
    integer :parrot_id
    integer :pirate_id
  end

  create_table :parrots_treasures, :id => false, :force => true do
    integer :parrot_id
    integer :treasure_id
  end

  create_table :people, :force => true do
    string     :first_name, :null => false
    references :primary_contact
    string     :gender, :limit => 1
    references :number1_fan
    integer    :lock_version, :null => false, :default => 0
    string     :comments
    references :best_friend
    references :best_friend_of
    timestamps
  end

  create_table :pets, :primary_key => :pet_id, :force => true do
    string :name
    integer :owner_id, :integer
    timestamps
  end

  create_table :pirates, :force => true do
    string :catchphrase
    integer :parrot_id
    integer :non_validated_parrot_id
    datetime :created_on
    datetime :updated_on
  end

  create_table :posts, :force => true do
    integer :author_id
    string  :title, :null => false
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      string  :body, :null => false, :limit => 4000
    else
      text    :body, :null => false
    end
    string  :type
    integer :comments_count, :default => 0
    integer :taggings_count, :default => 0
    integer :taggings_with_delete_all_count, :default => 0
    integer :taggings_with_destroy_count, :default => 0
    integer :tags_count, :default => 0
    integer :tags_with_destroy_count, :default => 0
    integer :tags_with_nullify_count, :default => 0
  end

  create_table :price_estimates, :force => true do
    string :estimate_of_type
    integer :estimate_of_id
    integer :price
  end

  create_table :products, :force => true do
    references :collection
    string     :name
  end

  create_table :projects, :force => true do
    string :name
    string :type
  end

  create_table :ratings, :force => true do
    integer :comment_id
    integer :value
  end

  create_table :readers, :force => true do
    integer :post_id, :null => false
    integer :person_id, :null => false
    boolean :skimmer, :default => false
  end

  create_table :references, :force => true do
    integer :person_id
    integer :job_id
    boolean :favourite
    integer :lock_version, :default => 0
  end

  create_table :shape_expressions, :force => true do
    string  :paint_type
    integer :paint_id
    string  :shape_type
    integer :shape_id
  end

  create_table :ships, :force => true do
    string :name
    integer :pirate_id
    integer :update_only_pirate_id
    datetime :created_at
    datetime :created_on
    datetime :updated_at
    datetime :updated_on
  end

  create_table :ship_parts, :force => true do
    string :name
    integer :ship_id
  end

  create_table :speedometers, :force => true, :id => false do
    string :speedometer_id
    string :name
    string :dashboard_id
  end

  create_table :sponsors, :force => true do
    integer :club_id
    integer :sponsorable_id
    string :sponsorable_type
  end

  create_table :string_key_objects, :id => false, :primary_key => :id, :force => true do
    string :id
    string :name
    integer :lock_version, :null => false, :default => 0
  end

  create_table :students, :force => true do
    string :name
  end

  create_table :subscribers, :force => true, :id => false do
    string :nick, :null => false
    string :name
  end
  add_index :subscribers, :nick, :unique => true

  create_table :subscriptions, :force => true do
    string :subscriber_id
    integer :book_id
  end

  create_table :tags, :force => true do
    string :name
    integer :taggings_count, :default => 0
  end

  create_table :taggings, :force => true do
    integer :tag_id
    integer :super_tag_id
    string :taggable_type
    integer :taggable_id
    string :comment
  end

  create_table :tasks, :force => true do
    datetime :starting
    datetime :ending
  end

  create_table :topics, :force => true do
    string   :title
    string   :author_name
    string   :author_email_address
    datetime :written_on
    time     :bonus_time
    date     :last_read
    # use VARCHAR2(4000) instead of CLOB datatype as CLOB data type has many limitations in
    # Oracle SELECT WHERE clause which causes many unit test failures
    if current_adapter?(:OracleAdapter)
      string   :content, :limit => 4000
    else
      text     :content
    end
    boolean  :approved, :default => true
    integer  :replies_count, :default => 0
    integer  :parent_id
    string   :parent_title
    string   :type
    string   :group
    timestamps
  end

  create_table :toys, :primary_key => :toy_id, :force => true do
    string :name
    integer :pet_id, :integer
    timestamps
  end

  create_table :traffic_lights, :force => true do
    string   :location
    string   :state
    datetime :created_at
    datetime :updated_at
  end

  create_table :treasures, :force => true do
    string :name
    integer :looter_id
    string :looter_type
  end

  create_table :tyres, :force => true do
    integer :car_id
  end

  create_table :variants, :force => true do
    references :product
    string     :name
  end

  create_table :vertices, :force => true do
    string :label
  end

  create_table 'warehouse-things', :force => true do
    integer :value
  end

  [:circles, :squares, :triangles, :non_poly_ones, :non_poly_twos].each do |table|
    create_table table, :force => true
  end

  # NOTE - the following 4 tables are used by models that have :inverse_of options on the associations
  create_table :men, :force => true do
    string  :name
  end

  create_table :faces, :force => true do
    string  :description
    integer :man_id
    integer :polymorphic_man_id
    string  :polymorphic_man_type
    integer :horrible_polymorphic_man_id
    string  :horrible_polymorphic_man_type
  end

  create_table :interests, :force => true do
    string :topic
    integer :man_id
    integer :polymorphic_man_id
    string :polymorphic_man_type
    integer :zine_id
  end

  create_table :wheels, :force => true do
    references :wheelable, :polymorphic => true
  end

  create_table :zines, :force => true do
    string :title
  end

  create_table :countries, :force => true, :id => false, :primary_key => 'country_id' do
    string :country_id
    string :name
  end
  create_table :treaties, :force => true, :id => false, :primary_key => 'treaty_id' do
    string :treaty_id
    string :name
  end
  create_table :countries_treaties, :force => true, :id => false do
    string :country_id, :null => false
    string :treaty_id, :null => false
    datetime :created_at
    datetime :updated_at
  end

  create_table :liquid, :force => true do
    string :name
  end
  create_table :molecules, :force => true do
    integer :liquid_id
    string :name
  end
  create_table :electrons, :force => true do
    integer :molecule_id
    string :name
  end
  create_table :weirds, :force => true do
    string 'a$b'
  end

  except 'SQLite' do
    # fk_test_has_fk should be before fk_test_has_pk
    create_table :fk_test_has_fk, :force => true do
      integer :fk_id, :null => false
    end

    create_table :fk_test_has_pk, :force => true

    execute "ALTER TABLE fk_test_has_fk ADD CONSTRAINT fk_name FOREIGN KEY (#{quote_column_name 'fk_id'}) REFERENCES #{quote_table_name 'fk_test_has_pk'} (#{quote_column_name 'id'})"

    execute "ALTER TABLE lessons_students ADD CONSTRAINT student_id_fk FOREIGN KEY (#{quote_column_name 'student_id'}) REFERENCES #{quote_table_name 'students'} (#{quote_column_name 'id'})"
  end
end

Course.connection.create_table :courses, :force => true do
  string :name, :null => false
end
