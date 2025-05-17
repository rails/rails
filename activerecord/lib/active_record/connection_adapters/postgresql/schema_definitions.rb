# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        extend ActiveSupport::Concern
        extend ConnectionAdapters::ColumnMethods::ClassMethods

        # Defines the primary key field.
        # Use of the native PostgreSQL UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the <tt>gen_random_uuid()</tt> function.
        #
        # To use a UUID primary key without any defaults, set the +:default+
        # option to +nil+:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: nil
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # You may also pass a custom stored procedure that returns a UUID or use a
        # different UUID generation function from another library.
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, **options)
          if type == :uuid
            options[:default] = options.fetch(:default, "gen_random_uuid()")
          end

          super
        end

        ##
        # :method: bigserial
        # :call-seq: bigserial(*names, **options)
        #
        # Adds a +bigserial+ column, which is a PostgreSQL auto-incrementing 64-bit integer.
        #
        # This is commonly used for primary keys or large counters that require a greater range
        # than +serial+ (which is 32-bit).
        #
        # Example:
        #
        #   t.bigserial :event_id
        #
        # You can also explicitly declare it as the primary key:
        #
        #   create_table :events, id: false do |t|
        #     t.bigserial :id, primary_key: true
        #   end
        #

        ##
        # :method: bit
        # :call-seq: bit(*names, **options)
        #
        # Adds a +bit+ column for storing fixed-length bit strings.
        #
        # This type is useful for compactly representing flags or settings as binary values.
        # By default, you can specify the number of bits the column should store.
        #
        # Example:
        #
        #   t.column :settings, "bit(8)"  # Stores exactly 8 bits
        #
        # When assigning values, use bit strings:
        #
        #   user = User.new
        #   user.settings = "01010101"  # This is a bit string
        #   user.save!

        ##
        # :method: bit_varying
        # :call-seq: bit_varying(*names, **options)
        #
        # Adds a +bit varying+ column for storing variable-length bit strings.
        #
        # This type is useful for representing binary flags, feature toggles, or compact
        # settings as sequences of bits.
        #
        # Example:
        #
        #   t.bit_varying :settings
        #
        # You can also specify the column type explicitly:
        #
        #   t.column :flags, 'bit varying(16)'  # Up to 16 bits
        #
        # Available options:
        #
        # - +:limit+ — Sets the maximum number of bits (e.g., +limit: 16+ → +bit varying(16)+)
        # - +:null+ — Whether the column allows +NULL+ values (e.g., +null: true+ or +null: false+)
        # - +:default+ — Sets a default bit string (e.g., +default: '1010'+)
        # - +:comment+ — Adds a comment to the column
        #
        # When assigning values, use bit strings:
        #
        #   user = User.new
        #   user.flags = "01010101"  # Valid bit string
        #   user.save!
        #
        # If you assign an integer, it will be converted to a bit string:
        #
        #   user = User.new
        #   user.flags = 42  # Stored as "00101010"
        #   user.save!
        #
        # If you assign a string that is not a valid bit string, it will raise an error:
        #
        #   user = User.new
        #   user.flags = "invalid"  # Raises a PostgreSQL error

        ##
        # :method: box
        # :call-seq: box(*names, **options)
        #
        # Adds a +box+ column for storing rectangular boxes in a 2D plane.
        #
        # The +box+ type is backed by PostgreSQL and represents a rectangle defined
        # by two opposite corner points (typically the upper right and lower left).
        #
        # Example:
        #
        #   t.box :bounds
        #
        # You can also specify the column type explicitly:
        #
        #   t.column :bounds, :box
        #
        # Values can be assigned using PostgreSQL box syntax:
        #
        #   Shape.create(bounds: '((1,1),(4,4))')
        #
        # This creates a rectangular box with opposite corners at (1,1) and (4,4).
        # PostgreSQL treats the order of the points as irrelevant for storage, but
        # typically the first point is considered the upper-right corner and the
        # second the lower-left. The box spans the area between those two points on a 2D plane.

        ##
        # :method: bytea
        # :call-seq: binary(*names, **options)
        #
        # Adds a binary column mapped to PostgreSQL’s +bytea+ type.
        #
        # This is commonly used to store raw binary data such as files, images, or other blobs.
        #
        # Example:
        #
        #   t.binary :payload
        #
        # You can assign binary data from a file like this:
        #
        #   data = File.read(Rails.root.join("tmp/output.pdf"))
        #   Document.create(payload: data)
        #
        #  🔗 See also:
        #
        # - PostgreSQL type definition: https://www.postgresql.org/docs/current/static/datatype-binary.html
        # - Hstore functions and operators: https://www.postgresql.org/docs/current/static/functions-binarystring.html

        ##
        # :method: cidr
        # :call-seq: cidr(*names, **options)
        #
        # Adds a +cidr+ column for storing IP addresses and network ranges.
        #
        # The +cidr+ stands for *Classless Inter-Domain Routing*.
        # It is used to store IP addresses along with their subnet masks, such as +'192.168.0.0/24'+.
        # The `cidr` type is mapped to Ruby [`IPAddr`](https://docs.ruby-lang.org/en/master/IPAddr.html)
        #
        # Example:
        #
        #   create_table(:devices, force: true) do |t|
        #     t.cidr "network"
        #   end
        #
        # Values can be assigned using standard PostgreSQL CIDR syntax:
        #
        #   device = Device.create(network: '192.168.0.0/24')
        #
        #   device.network
        #   => #<IPAddr: IPv4:192.168.0.0/255.255.255.0>
        #
        #  🔗 See also:
        #
        # - PostgreSQL type definition: https://www.postgresql.org/docs/current/static/datatype-net-types.html

        ##
        # :method: circle
        # :call-seq: circle(*names, **options)
        #
        # Adds a circle column for storing circular geometric objects.
        #
        # Example:
        #
        #   t.circle :bounds
        #
        # A circle value is stored as a center point and a radius. In SQL, the format is:
        #
        #   CIRCLE '((x, y), r)'
        #
        #   Circle.create(bounds: '((1,1),2)')
        #
        # This creates a circle centered at (1,1) with a radius of 2.

        ##
        # :method: citext
        # :call-seq: citext(*names, **options)
        #
        # Adds a +citext+ column for storing case-insensitive text values.
        #
        # This is backed by PostgreSQL’s +citext+ extension, which treats values
        # as case-insensitive for comparisons and indexing.
        #
        # Example:
        #
        #   t.citext :email
        #
        # This creates a column named +email+ that will treat values like "User@example.com"
        # and "user@example.com" as equal.

        ##
        # :method: daterange
        # :call-seq: daterange(*names, **options)
        #
        # Adds a +daterange+ column which allows storage and querying
        # of inclusive or exclusive date intervals.
        #
        # This type is mapped to Ruby [`Range`](https://docs.ruby-lang.org/en/master/Range.html) objects.
        #
        # Example:
        #   t.daterange :duration
        #
        # This creates a column named +duration+ that can store ranges like:
        #   '2024-01-01'..'2024-12-31'
        #
        #   Event.create(duration: Date.new(2014, 2, 11)..Date.new(2014, 2, 12))
        #
        #   event = Event.first
        #   event.duration
        #   => Tue, 11 Feb 2014...Thu, 13 Feb 2014
        #
        # For all events on a given date:
        #
        #   Event.where("duration @> ?::date", Date.new(2014, 2, 12))
        #
        # Working with range bounds:
        #
        #   event = Event.select("lower(duration) AS starts_at").select("upper(duration) AS ends_at").first
        #
        #   event.starts_at
        #   => Tue, 11 Feb 2014
        #
        #   event.ends_at
        #   => Thu, 13 Feb 2014
        #
        # 🔗 See also:
        #
        # - PostgreSQL type definition: https://www.postgresql.org/docs/current/static/rangetypes.html
        # - PostgreSQL range functions and operators: https://www.postgresql.org/docs/current/static/functions-range.html

        ##
        # The PostgreSQL +enum+ type can be used directly as a column, or mapped to
        # an [`ActiveRecord::Enum`](https://api.rubyonrails.org/classes/ActiveRecord/Enum.html)
        # to add model-level helpers and validations.
        #
        # Example: Creating an enum type and using it in a new table
        #
        #   # db/migrate/20131220144913_create_articles.rb
        #   def change
        #     create_enum :article_status, ["draft", "published", "archived"]
        #
        #     create_table :articles do |t|
        #       t.enum :status, enum_type: :article_status, default: "draft", null: false
        #     end
        #   end
        #
        # You can also create the enum and add it to an existing table:
        #
        #   # db/migrate/20230113024409_add_status_to_articles.rb
        #   def change
        #     create_enum :article_status, ["draft", "published", "archived"]
        #     add_column :articles, :status, :enum, enum_type: :article_status, default: "draft", null: false
        #   end
        #
        # The above migrations are reversible. If you need custom up/down logic:
        #
        #   def down
        #     drop_table :articles
        #     # OR: remove_column :articles, :status
        #     drop_enum :article_status
        #   end
        #
        # Make sure you remove any columns or tables that depend on the enum type before dropping it.
        #
        # Declaring enum in the model adds helper methods and prevents invalid values from being assigned to instances of the class:
        #
        #   # app/models/article.rb
        #   class Article < ApplicationRecord
        #     enum :status, {
        #       draft: "draft", published: "published", archived: "archived"
        #     }, prefix: true
        #   end
        #
        # Usage:
        #
        #   article = Article.create
        #   article.status
        #   # => "draft"
        #
        #   article.status_published!
        #   article.status
        #   # => "published"
        #
        #   article.status_archived?
        #   # => false
        #
        #   article.status = "deleted"
        #   # => ArgumentError: 'deleted' is not a valid status
        #
        # To rename an enum type:
        #
        #   def change
        #     rename_enum :article_status, :article_state
        #   end
        #
        # To add new values to an enum:
        #
        #   def up
        #     add_enum_value :article_state, "archived"                     # Appends at end
        #     add_enum_value :article_state, "in review", before: "published"
        #     add_enum_value :article_state, "approved", after: "in review"
        #     add_enum_value :article_state, "rejected", if_not_exists: true
        #   end
        #
        # NOTE: Enum values can't be dropped, so +add_enum_value+ is irreversible.
        # See: https://www.postgresql.org/message-id/29F36C7C98AB09499B1A209D48EAA615B7653DBC8A@mail2a.alliedtesting.com
        #
        # To rename an enum value:
        #
        #   def change
        #     rename_enum_value :article_state, from: "archived", to: "deleted"
        #   end
        #
        # To inspect all enum types and values in the database you can use this query in `bin/rails db` or `psql` console::
        #
        #   SELECT n.nspname AS enum_schema,
        #          t.typname AS enum_name,
        #          e.enumlabel AS enum_value
        #     FROM pg_type t
        #          JOIN pg_enum e ON t.oid = e.enumtypid
        #          JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace;

        ##
        # :method: hstore
        # :call-seq: hstore(*names, **options)
        #
        # Adds an +hstore+ column for storing sets of key-value pairs.
        #
        # PostgreSQL’s +hstore+ type allows you to store a dynamic set of string keys and values
        # in a single column. This is useful for flexible or semi-structured data such as user
        # preferences, metadata, or settings.
        #
        # You must enable the +hstore+ extension to use this type:
        #
        #   enable_extension "hstore" unless extension_enabled?("hstore")
        #
        # Example:
        #
        #   # db/migrate/20131009135255_create_profiles.rb
        #   class CreateProfiles < ActiveRecord::Migration[8.1]
        #     def change
        #       enable_extension "hstore" unless extension_enabled?("hstore")
        #
        #       create_table :profiles do |t|
        #         t.hstore :settings
        #       end
        #     end
        #   end
        #
        #   # app/models/profile.rb
        #   class Profile < ApplicationRecord
        #   end
        #
        #   Profile.create(settings: { "color" => "blue", "resolution" => "800x600" })
        #
        #   profile = Profile.first
        #   profile.settings
        #   # => {"color"=>"blue", "resolution"=>"800x600"}
        #
        #   profile.settings = { "color" => "yellow", "resolution" => "1280x1024" }
        #   profile.save!
        #
        #   Profile.where("settings -> 'color' = ?", "yellow")
        #
        # 🔗 See also:
        #
        # - PostgreSQL type definition: https://www.postgresql.org/docs/current/static/hstore.html
        # - Hstore functions and operators: https://www.postgresql.org/docs/current/static/hstore.html#id-1.11.7.26.5
        #
        # 💡 When to use hstore vs jsonb?
        #
        # Use +hstore+ when you need a simple, flat key-value store where both keys and values are strings.
        # It’s lightweight and efficient for storing unstructured settings or metadata. If you require nested
        # structures, typed values (e.g. numbers, booleans), or advanced querying capabilities, consider using
        # +jsonb+ instead.

        ##
        # :method: inet
        # :call-seq: inet(*names, **options)
        #
        # Adds an +inet+ column for storing IPv4 or IPv6 addresses with or without subnet masks.
        # In Ruby, this is mapped to an [`IPAddr`](https://docs.ruby-lang.org/en/master/IPAddr.html) object.
        #
        # Example:
        #
        #   create_table(:devices, force: true) do |t|
        #     t.inet "ip_address"
        #   end
        #
        # You can assign and query values as strings:
        #
        #   device = Device.create(ip_address: "192.168.1.1")
        #   device.ip_address.class
        #   # => IPAddr
        #
        #   device.ip_address
        #   => #<IPAddr: IPv4:192.168.1.12/255.255.255.255>
        #
        # 🔗 See also: [Ruby IPAddr documentation](https://docs.ruby-lang.org/en/master/IPAddr.html)

        ## :method: interval :call-seq: interval(*names, **options)
        #
        # Adds an +interval+ column for storing durations of time. It represents
        # elapsed time (e.g., hours, days, months). In Ruby, this maps to
        # +ActiveSupport::Duration+. This type is mapped to
        # [`ActiveSupport::Duration`](https://api.rubyonrails.org/classes/ActiveSupport/Duration.html)
        # objects.
        #
        # Example:
        #
        #  create_table :events do |t|
        #   t.interval "duration"
        # end
        #
        # You can assign durations using ActiveSupport helpers:
        #   event = Event.create(duration: 3.days + 2.hours)
        #   event.duration
        #   => 3 days 2 hours
        #

        ##
        # :method: int4range
        # :call-seq: int4range(*names, **options)
        #
        # Adds an +int4range+ column for storing a range of 32-bit integers.
        # It allows you to store inclusive or exclusive integer ranges (e.g., +[1,100)+).
        # Useful for modeling bounded numeric intervals such as ID blocks, scoring thresholds, or numeric quotas.
        #
        # Example:
        #
        #   t.int4range :range
        #
        # You can assign values using Ruby ranges:
        #
        #   record.range = 1...100

        ##
        # :method: int8range
        # :call-seq: int8range(*names, **options)
        #
        # Adds an +int8range+ column for storing a range of 64-bit integers.
        #
        # Backed by PostgreSQL’s +int8range+ type, this allows storage of larger integer ranges
        # than +int4range+, suitable for large ID spans, counters, or capacity models.
        #
        # Example:
        #
        #   t.int8range :usage_window
        #
        # You can assign values using Ruby ranges:
        #
        #   record.usage_window = 1_000_000..2_000_000

        ##
        # :method: jsonb
        # :call-seq: jsonb(*names, **options)
        #
        # Adds a +jsonb+ column for storing structured JSON data.
        #
        # PostgreSQL’s +jsonb+ type stores parsed binary JSON, allowing efficient access,
        # indexing, and advanced querying capabilities. It supports nested structures, typed values,
        # and complex documents.
        #
        # Example:
        #
        #   t.jsonb :payload
        #
        # You can also use +json+ (text-based JSON) instead:
        #
        #   t.json :payload
        #
        # The +json+ type preserves formatting and key order, while +jsonb+ is optimized for speed.
        #
        #   # db/migrate/20131220144913_create_events.rb
        #   create_table :events do |t|
        #     t.jsonb :payload
        #   end
        #
        #   # app/models/event.rb
        #   class Event < ApplicationRecord
        #   end
        #
        #   # Console usage:
        #   Event.create(payload: { kind: "user_renamed", change: ["jack", "john"] })
        #
        #   event = Event.first
        #   event.payload
        #   # => {"kind"=>"user_renamed", "change"=>["jack", "john"]}
        #
        # Query using PostgreSQL JSON operators:
        #
        #   # -> returns a JSON object or array (as JSON)
        #   # ->> returns a value as text
        #   Event.where("payload->>'kind' = ?", "user_renamed")
        #
        # 💡 Tip: Use +store_accessor+ to define typed accessors on +jsonb+ columns.
        #
        # 🔗 See also:
        #
        # - PostgreSQL JSON/JSONB type definition: https://www.postgresql.org/docs/current/static/datatype-json.html
        # - PostgreSQL JSON functions and operators: https://www.postgresql.org/docs/current/static/functions-json.html

        ##
        # :method: line
        # :call-seq: line(*names, **options)
        #
        # Adds a +line+ column for storing infinite straight lines in 2D space.
        #
        # Use when you want to model unbounded geometric or mathematical lines without start or end points.
        #
        # Example:
        #
        #   t.line :edge
        #
        # A line is defined by the general linear equation Ax + By + C = 0.
        #
        #   Shape.create(edge: '{1,2,3}')
        #
        # This creates a line with A=1, B=2, and C=3.

        ##
        # :method: lseg
        # :call-seq: lseg(*names, **options)
        #
        # Adds an +lseg+ column for storing finite line segments in 2D space.
        # Use when you need to represent physical boundaries, edge constraints, or defined routes.
        #
        # Example:
        #
        #   t.lseg :boundary
        #
        # An lseg value represents a straight segment between two points.
        #
        #   Wall.create(boundary: '[(0,0),(3,4)]')
        #
        # This creates a line segment from (0,0) to (3,4).

        ##
        # :method: ltree
        # :call-seq: ltree(*names, **options)
        #
        # Adds an +ltree+ column for storing labels in a hierarchical tree structure.
        #
        # Example:
        #
        #   enable_extension "ltree"
        #   t.ltree :path
        #
        # An ltree value represents a dot-separated path.
        #
        #   Node.create(path: 'Top.Science.Astronomy')
        #
        # This stores a path in a tree-like label hierarchy.

        ##
        # :method: macaddr
        # :call-seq: macaddr(*names, **options)
        #
        # Adds a +macaddr+ column for storing MAC addresses. It is mapped to normal text.
        #
        # Example:
        #
        #   t.macaddr :address
        #
        # A MAC address value must be in standard colon-separated format.
        #
        #   Device.create(address: '32:01:16:6d:05:ef')
        #
        #   device = Device.first
        #   device.address
        #   => "32:01:16:6d:05:ef"
        #
        # 🔗 See also: [Ruby IPAddr documentation](https://docs.ruby-lang.org/en/master/IPAddr.html)

        ##
        # :method: money
        # :call-seq: money(*names, **options)
        #
        # Adds a +money+ column for storing currency values.
        #
        # Example:
        #
        #   t.money :price
        #
        # A money value stores fixed-point currency, with locale-aware formatting.
        #
        #   Product.create(price: '19.99')

        ##
        # :method: numrange
        # :call-seq: numrange(*names, **options)
        #
        # Adds a +numrange+ column for storing ranges of numeric values.
        #
        # Example:
        #
        #   t.numrange :acceptable_range
        #
        # A numrange value represents an arbitrary-precision numeric interval.
        #
        #   Metric.create(acceptable_range: 1.5..10.0)

        ##
        # :method: oid
        # :call-seq: oid(*names, **options)
        #
        # Adds an +oid+ column for storing PostgreSQL object identifiers.
        #
        # Example:
        #
        #   t.oid :object_id
        #
        #   Record.create(object_id: 12345)

        ##
        # :method: path
        # :call-seq: path(*names, **options)
        #
        # Adds a +path+ column for storing open or closed geometric paths.
        #
        # Example:
        #
        #   t.path :trail
        #
        # A path value is a series of connected 2D points.
        #
        #   Trail.create(trail: '((0,0),(1,2),(2,4))')

        ##
        # :method: point
        # :call-seq: point(*names, **options)
        #
        # Adds a +point+ column for storing 2D coordinates.
        #
        # Example:
        #
        #   t.point :location
        #
        # A point is stored as a pair of x, y coordinates.
        #
        #   Place.create(location: '(3.5,4.5)')

        ##
        # :method: polygon
        # :call-seq: polygon(*names, **options)
        #
        # Adds a +polygon+ column for storing closed geometric shapes.
        #
        # Example:
        #
        #   t.polygon :area
        #
        # A polygon is defined by a sequence of at least three points.
        #
        #   Region.create(area: '((1,1),(2,3),(3,1))')

        ##
        # :method: serial
        # :call-seq: serial(*names, **options)
        #
        # Adds a +serial+ column for auto-incrementing integer values.
        #
        # Example:
        #
        #   t.serial :legacy_id
        #
        # Serial values automatically increment on insert.
        #
        #   Record.create # legacy_id will auto-increment

        ##
        # :method: timestamptz
        # :call-seq: timestamptz(*names, **options)
        #
        # Adds a timestamp column with time zone awareness.
        #
        # Example:
        #
        #   create_table :post, id: :uuid do |t|
        #     t.datetime :published_at
        #     # By default, Active Record will set the data type of this column to `timestamp without time zone`.
        #   end
        #
        # A timestamptz value stores time in UTC with session-local zone conversion.
        #
        #   Submission.create(submitted_at: Time.now)
        #
        # Rails uses +timestamp without time zone+ by default for datetime columns.
        # This can lead to confusion or bugs in apps dealing with multiple time zones.
        # [PostgreSQL best practices](https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_timestamp_.28without_time_zone.29) recommend that `timestamp with time zone` is used instead for timezone-aware timestamps.
        # This must be configured before it can be used for new migrations.
        #
        # To configure Rails to use timestamp with time zone +timestamptz+ instead:
        #
        #   # config/application.rb
        #   ActiveSupport.on_load(:active_record_postgresqladapter) do
        #     self.datetime_type = :timestamptz
        #   end
        #
        # 🔗 See also:
        # - PostgreSQL Date/Time Types: https://www.postgresql.org/docs/current/datatype-datetime.html

        ##
        # :method: tsrange
        # :call-seq: tsrange(*names, **options)
        #
        # Adds a +tsrange+ column for storing timestamp ranges without time zone.
        #
        # Example:
        #
        #   t.tsrange :maintenance_window
        #
        # A tsrange value represents an unzoned time interval.
        #
        #   Server.create(maintenance_window: Time.parse("2024-01-01 08:00")...Time.parse("2024-01-01 12:00"))

        ##
        # :method: tstzrange
        # :call-seq: tstzrange(*names, **options)
        #
        # Adds a +tstzrange+ column for storing timestamp ranges with time zone.
        #
        # Example:
        #
        #   t.tstzrange :active_period
        #
        # A tstzrange value represents a time interval in UTC, aware of time zones.
        #
        #   Campaign.create(active_period: Time.zone.parse("2024-06-01 10:00")..Time.zone.parse("2024-06-01 18:00"))

        ##
        # :method: tsvector
        # :call-seq: tsvector(*names, **options)
        #
        # Adds a +tsvector+ column for full-text search indexing.
        #
        # Example:
        #
        #   t.tsvector :document
        #
        # A tsvector value stores lexemes for efficient search.
        #
        #   Article.create(document: "The quick brown fox jumps over the lazy dog")

        ## :method: uuid :call-seq: uuid(*names, **options)
        #
        # Adds a +uuid+ column for storing Universally Unique Identifiers.
        #
        # UUIDs are 128-bit values used to uniquely identify records across
        # space and time. They're commonly used for primary keys or to reference
        # external systems.
        #
        # If you're using PostgreSQL < 13, enable one of the following
        # extensions to use UUIDs:
        #
        # - `pgcrypto` extension (PostgreSQL >= 9.4)
        # - `uuid-ossp` extension (for even earlier releases)
        #
        # Basic Example
        #
        #   t.uuid :external_id
        #
        #   record = Model.create(external_id: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
        #   record.external_id
        #   # => "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        #
        # You can specify `id: :uuid` when creating a table to use UUIDs as the primary key:
        #
        #   create_table :posts, id: :uuid do |t|
        #     t.string :title
        #     t.timestamps
        #   end
        #
        #   post = Post.create(title: "Hello UUID")
        #   post.id
        #   # => "1c263dc4-79fc-4eb6-b9a1-bc4a5c7ff207"
        #
        # You can also use UUIDs as foreign keys in associations:
        #
        #   create_table :comments, id: :uuid do |t|
        #     t.references :post, type: :uuid, foreign_key: true
        #   end
        #
        #   class Post < ApplicationRecord
        #     has_many :comments
        #   end
        #
        #   class Comment < ApplicationRecord
        #     belongs_to :post
        #   end
        #
        #   post = Post.create!
        #   comment = post.comments.create!
        #   comment.post_id
        #   # => same UUID as post.id
        #
        # 🔗 See also:
        # - PostgreSQL UUID type: https://www.postgresql.org/docs/current/datatype-uuid.html
        # - pgcrypto extension: https://www.postgresql.org/docs/current/pgcrypto.html
        # - uuid-ossp extension: https://www.postgresql.org/docs/current/uuid-ossp.html

        ##
        # :method: xml
        # :call-seq: xml(*names, **options)
        #
        # Adds an +xml+ column for storing XML-formatted data.
        #
        # Example:
        #
        #   t.xml :metadata
        #
        # XML values are stored as valid XML documents.
        #
        #   Document.create(metadata: '<note><to>User</to><body>Hello</body></note>')

        define_column_methods :bigserial, :bit, :bit_varying, :cidr, :citext, :daterange,
          :hstore, :inet, :interval, :int4range, :int8range, :jsonb, :ltree, :macaddr,
          :money, :numrange, :oid, :point, :line, :lseg, :box, :path, :polygon, :circle,
          :serial, :tsrange, :tstzrange, :tsvector, :uuid, :xml, :timestamptz, :enum
      end

      ExclusionConstraintDefinition = Struct.new(:table_name, :expression, :options) do
        def name
          options[:name]
        end

        def using
          options[:using]
        end

        def where
          options[:where]
        end

        def deferrable
          options[:deferrable]
        end

        def export_name_on_schema_dump?
          !ActiveRecord::SchemaDumper.excl_ignore_pattern.match?(name) if name
        end
      end

      UniqueConstraintDefinition = Struct.new(:table_name, :column, :options) do
        def name
          options[:name]
        end

        def deferrable
          options[:deferrable]
        end

        def using_index
          options[:using_index]
        end

        def nulls_not_distinct
          options[:nulls_not_distinct]
        end

        def export_name_on_schema_dump?
          !ActiveRecord::SchemaDumper.unique_ignore_pattern.match?(name) if name
        end

        def defined_for?(name: nil, column: nil, **options)
          options = options.slice(*self.options.keys)

          (name.nil? || self.name == name.to_s) &&
            (column.nil? || Array(self.column) == Array(column).map(&:to_s)) &&
            options.all? { |k, v| self.options[k].to_s == v.to_s }
        end
      end

      # = Active Record PostgreSQL Adapter \Table Definition
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        attr_reader :exclusion_constraints, :unique_constraints, :unlogged

        def initialize(*, **)
          super
          @exclusion_constraints = []
          @unique_constraints = []
          @unlogged = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables
        end

        def exclusion_constraint(expression, **options)
          exclusion_constraints << new_exclusion_constraint_definition(expression, options)
        end

        def unique_constraint(column_name, **options)
          unique_constraints << new_unique_constraint_definition(column_name, options)
        end

        def new_exclusion_constraint_definition(expression, options) # :nodoc:
          options = @conn.exclusion_constraint_options(name, expression, options)
          ExclusionConstraintDefinition.new(name, expression, options)
        end

        def new_unique_constraint_definition(column_name, options) # :nodoc:
          options = @conn.unique_constraint_options(name, column_name, options)
          UniqueConstraintDefinition.new(name, column_name, options)
        end

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :virtual
            type = options[:type]
          end

          super
        end

        private
          def valid_column_definition_options
            super + [:array, :using, :cast_as, :as, :type, :enum_type, :stored]
          end

          def aliased_types(name, fallback)
            fallback
          end

          def integer_like_primary_key_type(type, options)
            if type == :bigint || options[:limit] == 8
              :bigserial
            else
              :serial
            end
          end
      end

      # = Active Record PostgreSQL Adapter \Table
      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods

        # Adds an exclusion constraint.
        #
        #  t.exclusion_constraint("price WITH =, availability_range WITH &&", using: :gist, name: "price_check")
        #
        # See {connection.add_exclusion_constraint}[rdoc-ref:SchemaStatements#add_exclusion_constraint]
        def exclusion_constraint(...)
          @base.add_exclusion_constraint(name, ...)
        end

        # Removes the given exclusion constraint from the table.
        #
        #  t.remove_exclusion_constraint(name: "price_check")
        #
        # See {connection.remove_exclusion_constraint}[rdoc-ref:SchemaStatements#remove_exclusion_constraint]
        def remove_exclusion_constraint(...)
          @base.remove_exclusion_constraint(name, ...)
        end

        # Adds a unique constraint.
        #
        #  t.unique_constraint(:position, name: 'unique_position', deferrable: :deferred, nulls_not_distinct: true)
        #
        # Example:
        #
        #   create_table :items do |t|
        #     t.integer :position, null: false
        #     t.unique_constraint [:position], deferrable: :immediate
        #   end
        #
        # If you want to change an existing unique index to deferrable, you can
        # use +:using_index+ to create deferrable unique constraints.
        #
        #   add_unique_constraint :items, deferrable: :deferred, using_index: "index_items_on_position"
        #
        # Like foreign keys, unique constraints can be deferred by setting +:deferrable+ to either +:immediate+ or +:deferred+.
        # By default, +:deferrable+ is false and the constraint is always checked immediately.
        #
        # Deferrable constraints are useful when performing multiple related inserts or updates that may temporarily violate
        # the constraint but are resolved by the end of the transaction.
        #
        # You can read more about deferrable constraints in the [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS).
        #
        # See {connection.add_unique_constraint}[rdoc-ref:SchemaStatements#add_unique_constraint]
        def unique_constraint(...)
          @base.add_unique_constraint(name, ...)
        end

        # Removes the given unique constraint from the table.
        #
        #  t.remove_unique_constraint(name: "unique_position")
        #
        # See {connection.remove_unique_constraint}[rdoc-ref:SchemaStatements#remove_unique_constraint]
        def remove_unique_constraint(...)
          @base.remove_unique_constraint(name, ...)
        end

        # Validates the given constraint on the table.
        #
        #  t.check_constraint("price > 0", name: "price_check", validate: false)
        #  t.validate_constraint "price_check"
        #
        # See {connection.validate_constraint}[rdoc-ref:SchemaStatements#validate_constraint]
        def validate_constraint(...)
          @base.validate_constraint(name, ...)
        end

        # Validates the given check constraint on the table
        #
        #  t.check_constraint("price > 0", name: "price_check", validate: false)
        #  t.validate_check_constraint name: "price_check"
        #
        # See {connection.validate_check_constraint}[rdoc-ref:SchemaStatements#validate_check_constraint]
        def validate_check_constraint(...)
          @base.validate_check_constraint(name, ...)
        end
      end

      # = Active Record PostgreSQL Adapter Alter \Table
      class AlterTable < ActiveRecord::ConnectionAdapters::AlterTable
        attr_reader :constraint_validations, :exclusion_constraint_adds, :unique_constraint_adds

        def initialize(td)
          super
          @constraint_validations = []
          @exclusion_constraint_adds = []
          @unique_constraint_adds = []
        end

        def validate_constraint(name)
          @constraint_validations << name
        end

        def add_exclusion_constraint(expression, options)
          @exclusion_constraint_adds << @td.new_exclusion_constraint_definition(expression, options)
        end

        def add_unique_constraint(column_name, options)
          @unique_constraint_adds << @td.new_unique_constraint_definition(column_name, options)
        end
      end
    end
  end
end
