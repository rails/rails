# frozen_string_literal: true

ActiveRecord::Schema.define do
  enable_extension!("uuid-ossp", ActiveRecord::Base.connection)
  enable_extension!("pgcrypto",  ActiveRecord::Base.connection) if ActiveRecord::Base.connection.supports_pgcrypto_uuid?

  uuid_default = connection.supports_pgcrypto_uuid? ? {} : { default: "uuid_generate_v4()" }

  create_table :uuid_parents, id: :uuid, force: true, **uuid_default do |t|
    t.string :name
  end

  create_table :uuid_children, id: :uuid, force: true, **uuid_default do |t|
    t.string :name
    t.uuid :uuid_parent_id
  end

  create_table :defaults, force: true do |t|
    t.date :modified_date, default: -> { "CURRENT_DATE" }
    t.date :modified_date_function, default: -> { "now()" }
    t.date :fixed_date, default: "2004-01-01"
    t.datetime :modified_time, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime :modified_time_function, default: -> { "now()" }
    t.datetime :fixed_time, default: "2004-01-01 00:00:00.000000-00"
    t.timestamptz :fixed_time_with_time_zone, default: "2004-01-01 01:00:00+1"
    t.column :char1, "char(1)", default: "Y"
    t.string :char2, limit: 50, default: "a varchar field"
    t.text :char3, default: "a text field"
    t.bigint :bigint_default, default: -> { "0::bigint" }
    t.text :multiline_default, default: "--- []

"
  end

  create_table :postgresql_times, force: true do |t|
    t.interval :time_interval
    t.interval :scaled_time_interval, precision: 6
  end

  create_table :postgresql_oids, force: true do |t|
    t.oid :obj_id
  end

  drop_table "postgresql_timestamp_with_zones", if_exists: true
  drop_table "postgresql_partitioned_table", if_exists: true
  drop_table "postgresql_partitioned_table_parent", if_exists: true

  execute "DROP SEQUENCE IF EXISTS companies_nonstd_seq CASCADE"
  execute "CREATE SEQUENCE companies_nonstd_seq START 101 OWNED BY companies.id"
  execute "ALTER TABLE companies ALTER COLUMN id SET DEFAULT nextval('companies_nonstd_seq')"
  execute "DROP SEQUENCE IF EXISTS companies_id_seq"

  execute "DROP FUNCTION IF EXISTS partitioned_insert_trigger()"

  %w(accounts_id_seq developers_id_seq projects_id_seq topics_id_seq customers_id_seq orders_id_seq).each do |seq_name|
    execute "SELECT setval('#{seq_name}', 100)"
  end

  execute <<_SQL
  CREATE TABLE postgresql_timestamp_with_zones (
    id SERIAL PRIMARY KEY,
    time TIMESTAMP WITH TIME ZONE
  );
_SQL

  begin
    execute <<_SQL
    CREATE TABLE postgresql_partitioned_table_parent (
      id SERIAL PRIMARY KEY,
      number integer
    );
    CREATE TABLE postgresql_partitioned_table ( )
      INHERITS (postgresql_partitioned_table_parent);

    CREATE OR REPLACE FUNCTION partitioned_insert_trigger()
    RETURNS TRIGGER AS $$
    BEGIN
      INSERT INTO postgresql_partitioned_table VALUES (NEW.*);
      RETURN NULL;
    END;
    $$
    LANGUAGE plpgsql;

    CREATE TRIGGER insert_partitioning_trigger
      BEFORE INSERT ON postgresql_partitioned_table_parent
      FOR EACH ROW EXECUTE PROCEDURE partitioned_insert_trigger();
_SQL
  rescue ActiveRecord::StatementInvalid => e
    if e.message.include?('language "plpgsql" does not exist')
      execute "CREATE LANGUAGE 'plpgsql';"
      retry
    else
      raise e
    end
  end

  # This table is to verify if the :limit option is being ignored for text and binary columns
  create_table :limitless_fields, force: true do |t|
    t.binary :binary, limit: 100_000
    t.text :text, limit: 100_000
  end

  create_table :bigint_array, force: true do |t|
    t.integer :big_int_data_points, limit: 8, array: true
    t.decimal :decimal_array_default, array: true, default: [1.23, 3.45]
  end

  create_table :uuid_comments, force: true, id: false do |t|
    t.uuid :uuid, primary_key: true, **uuid_default
    t.string :content
  end

  create_table :uuid_entries, force: true, id: false do |t|
    t.uuid :uuid, primary_key: true, **uuid_default
    t.string :entryable_type, null: false
    t.uuid :entryable_uuid, null: false
  end

  create_table :uuid_items, force: true, id: false do |t|
    t.uuid :uuid, primary_key: true, **uuid_default
    t.string :title
  end

  create_table :uuid_messages, force: true, id: false do |t|
    t.uuid :uuid, primary_key: true, **uuid_default
    t.string :subject
  end

  if supports_partitioned_indexes?
    create_table(:measurements, id: false, force: true, options: "PARTITION BY LIST (city_id)") do |t|
      t.string :city_id, null: false
      t.date :logdate, null: false
      t.integer :peaktemp
      t.integer :unitsales
      t.index [:logdate, :city_id], unique: true
    end
    create_table(:measurements_toronto, id: false, force: true,
                                        options: "PARTITION OF measurements FOR VALUES IN (1)")
    create_table(:measurements_concepcion, id: false, force: true,
                                           options: "PARTITION OF measurements FOR VALUES IN (2)")
  end
end
