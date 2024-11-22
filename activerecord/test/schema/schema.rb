# frozen_string_literal: true

ActiveRecord::Schema.define do
  # ------------------------------------------------------------------- #
  #                                                                     #
  #   Please keep these create table statements in alphabetical order   #
  #   unless the ordering matters.  In which case, define them below.   #
  #                                                                     #
  # ------------------------------------------------------------------- #

  create_table :"1_need_quoting", force: true do |t|
    t.string :name
  end

  create_table :accounts, force: true do |t|
    t.references :firm, index: false
    t.string  :firm_name
    t.integer :credit_limit
    t.string :status
    t.integer "a" * max_identifier_length
    t.datetime :updated_at
  end

  create_table :admin_accounts, force: true do |t|
    t.string :name
  end

  create_table :admin_users, force: true do |t|
    t.string :name
    t.string :settings, null: true, limit: 1024
    t.string :parent, null: true, limit: 1024
    t.string :spouse, null: true, limit: 1024
    t.string :configs, null: true, limit: 1024
    # MySQL does not allow default values for blobs. Fake it out with a
    # big varchar below.
    t.string :preferences, null: true, default: "", limit: 1024
    t.string :json_data, null: true, limit: 1024
    t.string :json_data_empty, null: true, default: "", limit: 1024
    t.text :params
    t.references :account
    t.json :json_options
  end

  create_table :admin_user_jsons, force: true do |t|
    t.string :name
    t.string :settings, null: true, limit: 1024
    t.string :parent, null: true, limit: 1024
    t.string :spouse, null: true, limit: 1024
    t.string :configs, null: true, limit: 1024
    # MySQL does not allow default values for blobs. Fake it out with a
    # big varchar below.
    t.string :preferences, null: true, default: "", limit: 1024
    t.string :json_data, null: true, limit: 1024
    t.string :json_data_empty, null: true, default: "", limit: 1024
    t.text :params
    t.references :account
  end

  create_table :aircraft, force: true do |t|
    t.string :name
    t.integer :wheels_count, default: 0, null: false
    t.datetime :wheels_owned_at
    t.timestamp :manufactured_at, default: -> { "CURRENT_TIMESTAMP" }
  end

  create_table :articles, force: true do |t|
  end

  create_table :articles_magazines, force: true do |t|
    t.references :article
    t.references :magazine
  end

  create_table :articles_tags, force: true do |t|
    t.references :article
    t.references :tag
  end

  create_table :attachments, force: true do |t|
    t.references :record, polymorphic: true, null: false
  end

  create_table :audit_logs, force: true do |t|
    t.column :message, :string, null: false
    t.column :developer_id, :integer, null: false
    t.integer :unvalidated_developer_id
  end

  create_table :authors, force: true do |t|
    t.string :name, null: false
    t.references :author_address
    t.references :author_address_extra
    t.string :organization_id
    t.string :owned_essay_id
  end

  create_table :author_addresses, force: true do |t|
  end

  add_foreign_key :authors, :author_addresses, deferrable: :immediate

  create_table :author_favorites, force: true do |t|
    t.column :author_id, :integer
    t.column :favorite_author_id, :integer
  end

  create_table :auto_id_tests, force: true, id: false do |t|
    t.primary_key :auto_id
    t.integer     :value
  end

  create_table :binaries, force: true do |t|
    t.string :name
    t.binary :data
    t.binary :short_data, limit: 2048
    t.blob :blob_data
  end

  create_table :birds, force: true do |t|
    t.string :name
    t.string :color
    t.integer :pirate_id
  end

  create_table :books, id: :integer, force: true do |t|
    default_zero = { default: 0 }
    t.references :author
    t.string :format
    t.integer :format_record_id
    t.string :format_record_type
    t.column :name, :string
    t.column :status, :integer, **default_zero
    t.column :last_read, :integer, **default_zero
    t.column :nullable_status, :integer
    t.column :language, :integer, **default_zero
    t.column :author_visibility, :integer, **default_zero
    t.column :illustrator_visibility, :integer, **default_zero
    t.column :font_size, :integer, **default_zero
    t.column :difficulty, :integer, **default_zero
    t.column :cover, :string, default: "hard"
    t.column :symbol_status, :string, default: "proposed"
    t.string :isbn
    t.string :external_id
    t.column :original_name, :string
    t.datetime :published_on
    t.boolean :boolean_status
    t.index [:author_id, :name], unique: true
    t.integer :tags_count, default: 0
    t.index :isbn, where: "published_on IS NOT NULL", unique: true
    t.index "(lower(external_id))", unique: true if supports_expression_index?

    t.datetime :created_at
    t.datetime :updated_at
    t.date :updated_on
  end

  create_table :encrypted_books, id: :integer, force: true do |t|
    t.references :author
    t.string :format
    t.column :name, :string, default: "<untitled>", limit: 1024
    t.column :original_name, :string
    t.column :logo, :binary

    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :hardbacks, force: true do |t|
  end

  create_table :booleans, force: true do |t|
    t.boolean :value
    t.boolean :has_fun, null: false, default: false
  end

  create_table :branches, force: true do |t|
    t.references :branch
  end

  create_table :bulbs, primary_key: "ID", force: true do |t|
    t.integer :car_id
    t.string  :name
    t.boolean :frickinawesome, default: false
    t.string :color
  end

  create_table "CamelCase", force: true do |t|
    t.string :name
  end

  create_table :cars, force: true do |t|
    t.belongs_to :person
    t.string  :name
    t.integer :engines_count
    t.integer :wheels_count, default: 0, null: false
    t.datetime :wheels_owned_at
    t.integer :bulbs_count
    t.integer :custom_tyres_count
    t.column :lock_version, :integer, null: false, default: 0
    t.timestamps null: false
  end

  create_table :old_cars, id: :integer, force: true do |t|
  end

  create_table :carriers, force: true

  create_table :carts, force: true, primary_key: [:shop_id, :id] do |t|
    if ActiveRecord::TestCase.current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      t.bigint :id, index: true, auto_increment: true, null: false
    else
      t.bigint :id, index: true, null: false
    end
    t.bigint :shop_id
    t.string :title
  end

  create_table :categories, force: true do |t|
    t.string :name, null: false
    t.string :type
    t.integer :categorizations_count
  end

  create_table :categories_posts, force: true do |t|
    t.integer :category_id, null: false
    t.integer :post_id, null: false
  end

  create_table :categorizations, force: true do |t|
    t.column :category_id, :integer
    t.string :named_category_name
    t.column :post_id, :integer
    t.column :author_id, :integer
    t.column :special, :boolean
  end

  create_table :citations, force: true do |t|
    t.references :book1
    t.references :book2
    t.references :citation
  end

  create_table :cpk_books, primary_key: [:author_id, :id], force: true do |t|
    t.integer :author_id
    t.integer :id
    t.string :title
    t.integer :revision
    t.integer :order_id
    t.integer :shop_id
  end

  create_table :cpk_chapters, primary_key: [:author_id, :id], force: true do |t|
    t.integer :author_id
    t.integer :id
    t.integer :book_id
    t.string :title
  end

  create_table :cpk_authors, force: true do |t|
    t.string :name
  end

  create_table :cpk_posts, primary_key: [:title, :author], force: true do |t|
    t.string :title
    t.string :author
  end

  create_table :cpk_comments, force: true do |t|
    t.string :commentable_title
    t.string :commentable_author
    t.string :commentable_type
    t.text :text
  end

  create_table :cpk_reviews, force: true do |t|
    t.integer :author_id
    t.integer :number
    t.integer :rating
    t.string :comment
  end

  # not a composite primary key on the db level to get autoincrement behavior for `id` column
  # composite primary key is configured on the model level
  create_table :cpk_orders, force: true do |t|
    t.integer :shop_id
    t.string :status
    t.integer :books_count, default: 0
  end

  create_table :cpk_order_tags, primary_key: [:order_id, :tag_id], force: true do |t|
    t.integer :order_id
    t.integer :tag_id
    t.string :attached_by
    t.string :attached_reason
  end

  create_table :cpk_tags, force: true do |t|
    t.string :name, null: false
  end

  create_table :cpk_order_agreements, force: true do |t|
    t.integer :order_id
    t.string :signature

    t.index :order_id
  end

  create_table :cpk_cars, force: true, primary_key: [:make, :model] do |t|
    t.string :make, null: false
    t.string :model, null: false
  end

  create_table :cpk_car_reviews, force: true do |t|
    t.string :car_make, null: false
    t.string :car_model, null: false
    t.text :comment
    t.integer :rating
  end

  create_table :paragraphs, force: true do |t|
    t.references :book
  end

  create_table :clothing_items, force: true do |t|
    t.string :clothing_type
    t.string :color
    t.string :type
    t.string :size
    t.text :description

    t.index [:clothing_type, :color], unique: true
  end

  create_table :sharded_blogs, force: true do |t|
    t.string :name
  end

  create_table :sharded_blog_posts, force: true do |t|
    t.string :title
    t.references :parent, polymorphic: true
    t.integer :blog_id
    t.integer :revision
  end

  create_table :sharded_comments, force: true do |t|
    t.string :body
    t.integer :blog_post_id
    t.integer :blog_id
  end

  create_table :sharded_tags, force: true do |t|
    t.string :name
    t.integer :blog_id
  end

  create_table :sharded_blog_posts_tags, force: true do |t|
    t.integer :blog_id
    t.integer :blog_post_id
    t.integer :tag_id
  end

  create_table :clubs, force: true do |t|
    t.string :name
    t.integer :category_id
  end

  create_table :collections, force: true do |t|
    t.string :name
  end

  create_table :colnametests, force: true do |t|
    t.integer :references, null: false
  end

  create_table :columns, force: true do |t|
    t.references :record
  end

  create_table :comments, force: true do |t|
    t.integer :post_id, null: false
    t.text    :body, null: false
    t.string  :type
    t.integer :label, default: 0
    t.integer :tags_count, default: 0
    t.integer :children_count, default: 0
    t.integer :parent_id
    t.references :author, polymorphic: true
    # The type of the attribute is a string to make sure preload work when types don't match.
    # See #14855.
    t.string :resource_id
    t.string :resource_type
    t.integer :origin_id
    t.string :origin_type
    t.integer :developer_id
    t.datetime :updated_at
    t.datetime :deleted_at
    t.integer :comments
    t.integer :company
  end

  create_table :comment_overlapping_counter_caches, force: true do |t|
    t.integer :user_comments_count_id
    t.integer :post_comments_count_id
    t.references :commentable, polymorphic: true, index: false
  end

  create_table :companies, force: true do |t|
    t.string :type
    t.references :firm, index: false
    t.string  :firm_name
    t.string  :name
    t.bigint :client_of
    t.bigint :rating, default: 1
    t.integer :account_id
    t.string :description, default: ""
    t.integer :status, default: 0
    t.index [:name, :rating], order: :desc
    t.index [:name, :description], length: 10
    t.index [:firm_id, :type, :rating], name: "company_index", length: { type: 10 }, order: { rating: :desc }
    t.index [:firm_id, :type], name: "company_partial_index", where: "(rating > 10)"
    t.index [:firm_id], name: "company_nulls_not_distinct", nulls_not_distinct: true
    t.index :name, name: "company_name_index", using: :btree
    if supports_expression_index?
      t.index "(CASE WHEN rating > 0 THEN lower(name) END) DESC", name: "company_expression_index"
      if ActiveRecord::TestCase.current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        t.index "(CONCAT_WS(`firm_name`, `name`, _utf8mb4' '))", name: "full_name_index"
      end
    end
  end

  create_table :content, force: true do |t|
    t.string :title
    t.belongs_to :book
    t.belongs_to :book_destroy_async
  end

  create_table :content_positions, force: true do |t|
    t.integer :content_id
  end

  create_table :vegetables, force: true do |t|
    t.string :name
    t.integer :seller_id
    t.string :custom_type
  end

  create_table :computers, force: true do |t|
    t.string :system
    t.integer :developer, null: false
    t.integer :extendedWarranty, null: false
    t.integer :timezone
    t.timestamps
  end

  create_table :computers_developers, id: false, force: true do |t|
    t.references :computer
    t.references :developer
    t.timestamps
  end

  create_table :contracts, force: true do |t|
    t.references :developer, index: false
    t.references :company, index: false
    t.string :metadata
    t.integer :count
  end

  create_table :customers, force: true do |t|
    t.string  :name
    t.integer :balance, default: 0
    t.string  :address_street
    t.string  :address_city
    t.string  :address_country
    t.string  :gps_location
  end

  create_table :customer_carriers, force: true do |t|
    t.references :customer
    t.references :carrier
  end

  create_table :dashboards, force: true, id: false do |t|
    t.string :dashboard_id
    t.string :name
  end

  create_table :destroy_async_parents, force: true, id: false do |t|
    t.primary_key :parent_id
    t.string :name
    t.integer :tags_count, default: 0
  end

  create_table :destroy_async_parent_soft_deletes, force: true do |t|
    t.integer :tags_count, default: 0
    t.boolean :deleted
  end

  create_table :discounts, force: true do |t|
    t.integer :amount
  end

  create_table :dl_keyed_belongs_tos, force: true, id: false do |t|
    t.primary_key :belongs_key
    t.references :destroy_async_parent
  end

  create_table :dl_keyed_belongs_to_soft_deletes, force: true do |t|
    t.references :destroy_async_parent_soft_delete, index: { name: :soft_del_parent }
    t.boolean :deleted
  end

  create_table :dl_keyed_has_ones, force: true, id: false do |t|
    t.primary_key :has_one_key

    t.references :destroy_async_parent
    t.references :destroy_async_parent_soft_delete
  end

  create_table :dl_keyed_has_manies, force: true, id: false do |t|
    t.primary_key :many_key
    t.references :destroy_async_parent
  end

  create_table :dl_keyed_has_many_throughs, force: true, id: false do |t|
    t.primary_key :through_key
  end

  create_table :dl_keyed_joins, force: true, id: false do |t|
    t.primary_key :joins_key
    t.references :destroy_async_parent
    t.references :dl_keyed_has_many_through
  end

  create_table :developers, force: true do |t|
    t.string   :name
    t.string   :first_name
    t.integer  :salary, default: 70000
    t.references :firm, index: false
    t.integer :mentor_id
    t.datetime :legacy_created_at
    t.datetime :legacy_updated_at
    t.datetime :legacy_created_on
    t.datetime :legacy_updated_on
  end

  create_table :developers_projects, force: true, id: false do |t|
    t.integer :developer_id, null: false
    t.integer :project_id, null: false
    t.date    :joined_on
    t.integer :access_level, default: 1
  end

  create_table :dog_lovers, force: true do |t|
    t.integer :trained_dogs_count, default: 0
    t.integer :bred_dogs_count, default: 0
    t.integer :dogs_count, default: 0
  end

  create_table :dogs, force: true do |t|
    t.integer :trainer_id
    t.integer :breeder_id
    t.integer :dog_lover_id
    t.string  :alias
  end

  create_table :doubloons, force: true do |t|
    t.integer :pirate_id
    t.integer :weight
  end

  create_table :edges, force: true, id: false do |t|
    t.column :source_id, :integer, null: false
    t.column :sink_id,   :integer, null: false
    t.index [:source_id, :sink_id], unique: true, name: "unique_edge_index"
  end

  create_table :editorships, force: true do |t|
    t.string :publication_id
    t.string :editor_id
  end

  create_table :editors, force: true do |t|
    t.string :name
  end

  create_table :engines, force: true do |t|
    t.references :car, index: false
  end

  create_table :entrants, force: true do |t|
    t.string  :name, null: false
    t.integer :course_id, null: false
  end

  create_table :entries, force: true do |t|
    t.string   :entryable_type, null: false
    t.integer  :entryable_id, null: false
    t.integer  :account_id, null: false
    t.datetime :updated_at
  end

  create_table :essays, force: true do |t|
    t.string :type
    t.string :name
    t.string :writer_id
    t.string :writer_type
    t.string :category_id
    t.string :author_id
    t.references :book
  end

  create_table :events, force: true do |t|
    t.string :title, limit: 5
  end

  create_table :eyes, force: true do |t|
  end

  create_table :families, force: true do |t|
  end

  create_table :family_trees, force: true do |t|
    t.references :family
    t.references :member
    t.string :token
  end

  create_table :frogs, force: true do |t|
    t.string :name
  end

  create_table :funny_jokes, force: true do |t|
    t.string :name
  end

  create_table :cold_jokes, force: true do |t|
    t.string :cold_name
  end

  create_table :friendships, force: true do |t|
    t.integer :friend_id
    t.integer :follower_id
  end

  create_table :goofy_string_id, force: true, id: false do |t|
    t.string :id, null: false
    t.string :info
  end

  create_table :having, force: true do |t|
    t.string :where
  end

  create_table :guids, force: true do |t|
    t.column :key, :string
  end

  create_table :guitars, force: true do |t|
    t.string :color
  end

  create_table :inept_wizards, force: true do |t|
    t.column :name, :string, null: false
    t.column :city, :string, null: false
    t.column :type, :string
  end

  create_table :integer_limits, force: true do |t|
    t.integer :"c_int_without_limit"
    (1..8).each do |i|
      t.integer :"c_int_#{i}", limit: i
    end
  end

  create_table :invoices, force: true do |t|
    t.integer :balance
    t.datetime :updated_at
  end

  create_table :iris, force: true do |t|
    t.references :eye
    t.string     :color
  end

  create_table :items, force: true do |t|
    t.column :name, :string
  end

  create_table :jobs, force: true do |t|
    t.integer :ideal_reference_id
  end

  create_table :jobs_pool, force: true, id: false do |t|
    t.references :job, null: false, index: true
    t.references :user, null: false, index: true
  end

  create_table :keyboards, force: true, id: false do |t|
    t.primary_key :key_number
    t.string      :name
  end

  create_table :kitchens, force: true do |t|
  end

  create_table :legacy_things, force: true do |t|
    t.integer :tps_report_number
    t.integer :version, null: false, default: 0
  end

  create_table :lessons, force: true do |t|
    t.string :name
  end

  create_table :lessons_students, id: false, force: true do |t|
    t.references :lesson
    t.references :student
  end

  create_table :students, force: true do |t|
    t.string :name
    t.boolean :active
    t.integer :college_id
  end

  add_foreign_key :lessons_students, :students, on_delete: :cascade, deferrable: :immediate

  create_table :lint_models, force: true

  create_table :line_items, force: true do |t|
    t.integer :invoice_id
    t.integer :amount
  end

  create_table :line_item_discount_applications, force: true do |t|
    t.integer :line_item_id
    t.integer :discount_id
  end

  create_table :lions, force: true do |t|
    t.integer :gender
    t.boolean :is_vegetarian, default: false
  end

  create_table :lock_without_defaults, force: true do |t|
    t.column :title, :string
    t.column :lock_version, :integer
    t.timestamps null: true
  end

  create_table :lock_without_defaults_cust, force: true do |t|
    t.column :title, :string
    t.column :custom_lock_version, :integer
    t.timestamps null: true
  end

  create_table :magazines, force: true do |t|
  end

  create_table :mateys, id: false, force: true do |t|
    t.column :pirate_id, :integer
    t.column :target_id, :integer
    t.column :weight, :integer
  end

  create_table :members, force: true do |t|
    t.string :name
    t.references :member_type, index: false
    t.references :admittable, polymorphic: true, index: false
  end

  create_table :member_details, force: true do |t|
    t.integer :member_id
    t.integer :organization_id
    t.string :extra_data
  end

  create_table :member_friends, force: true, id: false do |t|
    t.integer :member_id
    t.integer :friend_id
  end

  create_table :memberships, force: true do |t|
    t.datetime :joined_on
    t.integer :club_id, :member_id
    t.boolean :favorite, default: false
    t.integer :type
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :member_types, force: true do |t|
    t.string :name
  end

  create_table :mentors, force: true do |t|
    t.string :name
  end

  create_table :messages, force: true do |t|
    t.string   :subject
    t.datetime :updated_at
  end

  create_table :minivans, force: true, id: false do |t|
    t.string :minivan_id
    t.string :name
    t.string :speedometer_id
    t.string :color
  end

  create_table :minimalistics, force: true do |t|
    t.bigint :expires_at
  end

  create_table :mixed_case_monkeys, force: true, id: false do |t|
    t.primary_key :monkeyID
    t.integer     :fleaCount
  end

  create_table :mixins, force: true do |t|
    t.integer  :parent_id
    t.integer  :pos
    t.datetime :created_at
    t.datetime :updated_at
    t.integer  :lft
    t.integer  :rgt
    t.integer  :root_id
    t.string   :type
  end

  create_table :mice, force: true do |t|
    t.string   :name
  end

  create_table :movies, force: true, id: false do |t|
    t.primary_key :movieid
    t.string      :name
  end

  create_table :notifications, force: true do |t|
    t.string :message
  end

  create_table :numeric_data, force: true do |t|
    t.decimal :bank_balance, precision: 10, scale: 2
    t.decimal :big_bank_balance, precision: 15, scale: 2
    t.decimal :unscaled_bank_balance, precision: 10
    t.decimal :world_population, precision: 20, scale: 0
    t.decimal :my_house_population, precision: 2, scale: 0
    t.decimal :decimal_number
    t.decimal :decimal_number_with_default, precision: 3, scale: 2, default: 2.78
    t.numeric :numeric_number
    t.float   :temperature
    t.float   :temperature_with_limit, limit: 24
    t.decimal :decimal_number_big_precision, precision: 20
    t.decimal :atoms_in_universe, precision: 55, scale: 0
  end

  create_table :orders, force: true do |t|
    t.string  :name
    t.integer :billing_customer_id
    t.integer :shipping_customer_id
  end

  create_table :organizations, force: true do |t|
    t.string :name
  end

  create_table :owners, primary_key: :owner_id, force: true do |t|
    t.string :name
    t.column :updated_at, :datetime
    t.column :happy_at,   :datetime
    t.string :essay_id
  end

  create_table :paint_colors, force: true do |t|
    t.integer :non_poly_one_id
  end

  create_table :paint_textures, force: true do |t|
    t.integer :non_poly_two_id
  end

  disable_referential_integrity do
    create_table :parrots, force: :cascade do |t|
      t.string :name
      t.integer :breed, default: 0
      t.string :color
      t.string :parrot_sti_class
      t.integer :killer_id
      t.integer :updated_count, :integer, default: 0
      t.datetime :created_at, precision: 0
      t.datetime :created_on, precision: 0
      t.datetime :updated_at, precision: 0
      t.datetime :updated_on, precision: 0
    end

    create_table :pirates, force: :cascade do |t|
      t.string :catchphrase
      t.integer :parrot_id
      t.integer :non_validated_parrot_id
      t.datetime :created_on
      t.datetime :updated_on
    end

    create_table :treasures, force: :cascade do |t|
      t.string :name
      t.string :type
      t.references :looter, polymorphic: true
      t.references :ship
    end

    create_table :parrots_pirates, id: false, force: true do |t|
      t.references :parrot, foreign_key: true
      t.references :pirate, foreign_key: true
    end

    # used by tests that do `Parrot.has_and_belongs_to_many :treasures` (the default)
    create_table :parrots_treasures, id: false, force: true do |t|
      t.references :parrot, foreign_key: true
      t.references :treasure, foreign_key: true
    end

    # used by tests that do `Parrot.has_many :treasures, through: :parrot_treasures`, and don't want to override the through relation's `table_name`
    create_table :parrot_treasures, id: false, force: true do |t|
      t.references :parrot, foreign_key: true
      t.references :treasure, foreign_key: true
    end
  end

  create_table :people, force: true do |t|
    t.string     :first_name, null: false
    t.references :primary_contact
    t.string     :gender, limit: 1
    t.references :number1_fan
    t.integer    :lock_version, null: false, default: 0
    t.string     :comments
    t.integer    :followers_count, default: 0
    t.integer    :friends_too_count, default: 0
    t.references :best_friend
    t.references :best_friend_of
    t.integer    :insures, null: false, default: 0
    t.timestamp :born_at
    t.integer :cars_count, default: 0
    t.timestamps null: false
  end

  create_table :peoples_treasures, id: false, force: true do |t|
    t.column :rich_person_id, :integer
    t.column :treasure_id, :integer
  end

  create_table :personal_legacy_things, force: true do |t|
    t.integer :tps_report_number
    t.integer :person_id
    t.integer :version, null: false, default: 0
  end

  create_table :pets, primary_key: :pet_id, force: true do |t|
    t.string :name
    t.integer :owner_id, :integer
    t.timestamps
  end

  create_table :pets_treasures, force: true do |t|
    t.column :treasure_id, :integer
    t.column :pet_id, :integer
    t.column :rainbow_color, :string
  end

  create_table :posts, force: true do |t|
    t.references :author
    t.string :title, null: false
    t.text    :body, null: false
    t.string  :type
    t.integer :legacy_comments_count, default: 0
    t.integer :taggings_with_delete_all_count, default: 0
    t.integer :taggings_with_destroy_count, default: 0
    t.integer :tags_count, default: 0
    t.integer :indestructible_tags_count, default: 0
    t.integer :tags_with_destroy_count, default: 0
    t.integer :tags_with_nullify_count, default: 0
  end

  create_table :postesques, force: true do |t|
    t.string :author_name
    t.string :author_id
  end

  create_table :post_comments_counts, force: true do |t|
    t.integer :comments_count, default: 0
  end

  create_table :serialized_posts, force: true do |t|
    t.integer :author_id
    t.string :title, null: false
  end

  create_table :images, force: true do |t|
    t.integer :imageable_identifier
    t.string :imageable_class
  end

  create_table :price_estimates, force: true do |t|
    t.string :estimate_of_type
    t.integer :estimate_of_id
    t.integer :price
    t.string :currency
  end

  create_table :products, force: true do |t|
    t.references :collection
    t.references :type
    t.string :name
    t.decimal :price
    t.decimal :discounted_price
  end

  add_check_constraint :products, "price > discounted_price", name: "products_price_check"

  create_table :product_types, force: true do |t|
    t.string :name
  end

  create_table :projects, force: true do |t|
    t.string :name
    t.string :type
    t.references :firm, index: false
    t.integer :mentor_id
  end

  create_table :publications, force: true do |t|
    t.column :name, :string
    t.integer :editor_in_chief_id
  end

  create_table :randomly_named_table1, force: true do |t|
    t.string  :some_attribute
    t.integer :another_attribute
  end

  create_table :randomly_named_table2, force: true do |t|
    t.string  :some_attribute
    t.integer :another_attribute
  end

  create_table :randomly_named_table3, force: true do |t|
    t.string  :some_attribute
    t.integer :another_attribute
  end

  create_table :ratings, force: true do |t|
    t.integer :comment_id
    t.integer :value
  end

  create_table :readers, force: true do |t|
    t.integer :post_id, null: false
    t.integer :person_id, null: false
    t.boolean :skimmer, default: false
    t.integer :first_post_id
  end

  create_table :references, force: true do |t|
    t.integer :person_id
    t.integer :job_id
    t.boolean :favorite
    t.integer :lock_version, default: 0
  end

  create_table :rooms, force: true do |t|
    t.references :user
    t.references :owner
    t.references :landlord
    t.references :tenant
  end

  disable_referential_integrity do
    create_table :seminars, force: :cascade do |t|
      t.string :name
    end

    create_table :sessions, force: :cascade do |t|
      t.date :start_date
      t.date :end_date
      t.string :name
    end

    create_table :sections, force: :cascade do |t|
      t.string :short_name
      t.belongs_to :session, foreign_key: true
      t.belongs_to :seminar, foreign_key: true
    end
  end

  create_table :shape_expressions, force: true do |t|
    t.string  :paint_type
    t.integer :paint_id
    t.string  :shape_type
    t.integer :shape_id
  end

  create_table :shipping_lines, force: true do |t|
    t.integer :invoice_id
    t.integer :amount
  end

  create_table :shipping_line_discount_applications, force: true do |t|
    t.integer :shipping_line_id
    t.integer :discount_id
  end

  create_table :ships, force: true do |t|
    t.string :name
    t.integer :pirate_id
    t.belongs_to :developer
    t.integer :update_only_pirate_id
    # Conventionally named column for counter_cache
    t.integer :treasures_count, default: 0
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
  end

  create_table :ship_parts, force: true do |t|
    t.string :name
    t.integer :ship_id
    t.datetime :updated_at
  end

  create_table :squeaks, force: true do |t|
    t.integer :mouse_id
  end

  create_table :prisoners, force: true do |t|
    t.belongs_to :ship
  end

  create_table :sinks, force: true do |t|
    t.references :kitchen
  end

  create_table :shop_accounts, force: true do |t|
    t.references :customer
    t.references :customer_carrier
  end

  create_table :speedometers, force: true, id: false do |t|
    t.string :speedometer_id
    t.string :name
    t.string :dashboard_id
  end

  create_table :sponsors, force: true do |t|
    t.integer :club_id
    t.references :sponsorable, polymorphic: true, index: false
    t.references :sponsor, polymorphic: true, index: false
  end

  create_table :string_key_objects, id: false, force: true do |t|
    t.string :id, null: false
    t.string :name
    t.integer :lock_version, null: false, default: 0
    t.index :id, unique: true
  end

  create_table :subscribers, id: false, force: true do |t|
    t.string :nick, null: false
    t.string :name
    t.integer :id
    t.integer :books_count, null: false, default: 0
    t.integer :update_count, null: false, default: 0
    t.index :nick, unique: true
  end

  create_table :subscriptions, force: true do |t|
    t.string :subscriber_id
    t.integer :book_id
  end

  create_table :tags, force: true do |t|
    t.column :name, :string
    t.column :taggings_count, :integer, default: 0
  end

  create_table :taggings, force: true do |t|
    t.column :tag_id, :integer
    t.column :super_tag_id, :integer
    t.column :taggable_type, :string
    t.column :taggable_id, :integer
    t.string :comment
    t.string :type
  end

  create_table :tasks, force: true do |t|
    t.datetime :starting
    t.datetime :ending
  end

  create_table :topics, force: true do |t|
    t.string   :title, limit: 250
    t.string   :author_name
    t.string   :author_email_address
    t.datetime :written_on
    t.time     :bonus_time
    t.date     :last_read
    t.text     :content
    t.text     :important
    t.blob     :binary_content
    t.boolean  :approved, default: true
    t.integer  :replies_count, default: 0
    t.integer  :unique_replies_count, default: 0
    t.integer  :parent_id
    t.string   :parent_title
    t.string   :type
    t.string   :group
    t.timestamps null: true
    t.index [:author_name, :title]
  end

  create_table :toys, primary_key: :toy_id, force: true do |t|
    t.string :name
    t.integer :pet_id, :integer
    t.timestamps null: false
  end

  create_table :traffic_lights, force: true do |t|
    t.string   :location
    t.string   :state
    t.text     :long_state, null: false
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :translations, force: true do |t|
    t.string :locale, null: false
    t.string :key, null: false
    t.string :value, null: false
    t.references :attachment
  end

  create_table :tuning_pegs, force: true do |t|
    t.integer :guitar_id
    t.float :pitch
  end

  create_table :tyres, force: true do |t|
    t.integer :car_id
  end

  create_table :unused_destroy_asyncs, force: true do |t|
  end

  create_table :unused_belongs_to, force: true do |t|
    t.belongs_to :unused_destroy_async
  end

  create_table :variants, force: true do |t|
    t.references :product
    t.string     :name
  end

  create_table :vertices, force: true do |t|
    t.column :label, :string
  end

  create_table "warehouse-things", force: true do |t|
    t.integer :value
  end

  [:circles, :squares, :triangles, :non_poly_ones, :non_poly_twos].each do |t|
    create_table(t, force: true) { }
  end

  create_table :humans, force: true do |t|
    t.string  :name
  end

  create_table :faces, force: true do |t|
    t.string  :description
    t.integer :human_id
    t.integer :polymorphic_human_id
    t.string  :polymorphic_human_type
    t.integer :poly_human_without_inverse_id
    t.string  :poly_human_without_inverse_type
    t.integer :puzzled_polymorphic_human_id
    t.string  :puzzled_polymorphic_human_type
    t.references :super_human, polymorphic: true, index: false
  end

  create_table :interests, force: true do |t|
    t.string :topic
    t.integer :human_id
    t.integer :polymorphic_human_id
    t.string :polymorphic_human_type
    t.integer :zine_id
  end

  create_table :zines, force: true do |t|
    t.string :title
  end

  create_table :strict_zines, force: true do |t|
    t.string :title
  end

  create_table :wheels, force: true do |t|
    t.integer :size
    t.references :wheelable, polymorphic: true
  end

  create_table :countries, force: true, id: false do |t|
    t.string :country_id, primary_key: true
    t.string :name
  end

  create_table :treaties, force: true, id: false do |t|
    t.string :treaty_id, primary_key: true
    t.string :name
  end

  create_table :countries_treaties, force: true, primary_key: [:country_id, :treaty_id] do |t|
    t.string :country_id, null: false
    t.string :treaty_id, null: false
  end

  create_table :liquid, force: true do |t|
    t.string :name
  end
  create_table :molecules, force: true do |t|
    t.integer :liquid_id
    t.string :name
  end
  create_table :electrons, force: true do |t|
    t.integer :molecule_id
    t.string :name
  end
  create_table :weirds, force: true do |t|
    t.string "a$b"
    t.string "なまえ"
    t.string "from"
  end

  create_table :nodes, force: true do |t|
    t.integer :tree_id
    t.integer :parent_id
    t.string :name
    t.datetime :updated_at
  end
  create_table :trees, force: true do |t|
    t.string :name
    t.datetime :updated_at
  end

  create_table :hotels, force: true do |t|
  end
  create_table :departments, force: true do |t|
    t.integer :hotel_id
  end
  create_table :cake_designers, force: true do |t|
  end
  create_table :drink_designers, force: true do |t|
    t.string :name
  end
  create_table :chefs, force: true do |t|
    t.integer :employable_id
    t.string :employable_type
    t.integer :department_id
    t.string :employable_list_type
    t.integer :employable_list_id
    t.timestamps
  end
  create_table :recipes, force: true do |t|
    t.integer :chef_id
    t.integer :hotel_id
  end

  create_table :recipients, force: true do |t|
    t.integer  :message_id
    t.string   :email_address
  end

  create_table :records, force: true do |t|
  end

  disable_referential_integrity do
    create_table :fk_test_has_pk, primary_key: "pk_id", force: :cascade do |t|
    end

    create_table :fk_test_has_fk, force: true do |t|
      t.references :fk, null: false
      t.foreign_key :fk_test_has_pk, column: "fk_id", name: "fk_name", primary_key: "pk_id"
    end
  end

  disable_referential_integrity do
    create_table :fk_object_to_point_tos, force: :cascade do |t|
    end

    create_table :fk_pointing_to_non_existent_objects, force: true do |t|
      t.references :fk_object_to_point_to, null: false, index: false
      t.foreign_key :fk_object_to_point_tos, column: "fk_object_to_point_to_id", name: "fk_that_will_be_broken"
    end
  end

  create_table :overloaded_types, force: true do |t|
    t.float :overloaded_float, default: 500
    t.float :unoverloaded_float
    t.string :overloaded_string_with_limit, limit: 255
    t.string :string_with_default, default: "the original default"
    t.string :inferred_string, limit: 255
    t.datetime :starts_at, :ends_at
  end

  create_table :users, force: true do |t|
    t.string :token
    t.string :auth_token
    t.string :password_digest
    t.string :recovery_password_digest
    t.timestamps null: true
  end

  create_table :user_comments_counts, force: true do |t|
    t.integer :comments_count, default: 0
  end

  create_table :test_with_keyword_column_name, force: true do |t|
    t.string :desc
  end

  create_table :non_primary_keys, force: true, id: false do |t|
    t.integer :id
    t.datetime :created_at
  end

  create_table :toooooooooooooooooooooooooooooooooo_long_table_names, force: true do |t|
    t.bigint :toooooooo_long_a_id, null: false
    t.bigint :toooooooo_long_b_id, null: false
  end
end

Course.lease_connection.create_table :courses, force: true do |t|
  t.column :name, :string, null: false
  t.column :college_id, :integer, index: true
end

College.lease_connection.create_table :colleges, force: true do |t|
  t.column :name, :string, null: false
end

Professor.lease_connection.create_table :professors, force: true do |t|
  t.column :name, :string, null: false
end

Professor.lease_connection.create_table :courses_professors, id: false, force: true do |t|
  t.references :course
  t.references :professor
end

OtherDog.lease_connection.create_table :dogs, force: true
