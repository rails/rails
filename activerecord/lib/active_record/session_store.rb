require 'action_dispatch/middleware/session/abstract_store'

module ActiveRecord
  # = Active Record Session Store
  #
  # A session store backed by an Active Record class. A default class is
  # provided, but any object duck-typing to an Active Record Session class
  # with text +session_id+ and +data+ attributes is sufficient.
  #
  # The default assumes a +sessions+ tables with columns:
  #   +id+ (numeric primary key),
  #   +session_id+ (text, or longtext if your session data exceeds 65K), and
  #   +data+ (text or longtext; careful if your session data exceeds 65KB).
  #
  # The +session_id+ column should always be indexed for speedy lookups.
  # Session data is marshaled to the +data+ column in Base64 format.
  # If the data you write is larger than the column's size limit,
  # ActionController::SessionOverflowError will be raised.
  #
  # You may configure the table name, primary key, and data column.
  # For example, at the end of <tt>config/application.rb</tt>:
  #
  #   ActiveRecord::SessionStore::Session.table_name = 'legacy_session_table'
  #   ActiveRecord::SessionStore::Session.primary_key = 'session_id'
  #   ActiveRecord::SessionStore::Session.data_column_name = 'legacy_session_data'
  #
  # Note that setting the primary key to the +session_id+ frees you from
  # having a separate +id+ column if you don't want it. However, you must
  # set <tt>session.model.id = session.session_id</tt> by hand!  A before filter
  # on ApplicationController is a good place.
  #
  # Since the default class is a simple Active Record, you get timestamps
  # for free if you add +created_at+ and +updated_at+ datetime columns to
  # the +sessions+ table, making periodic session expiration a snap.
  #
  # You may provide your own session class implementation, whether a
  # feature-packed Active Record or a bare-metal high-performance SQL
  # store, by setting
  #
  #   ActiveRecord::SessionStore.session_class = MySessionClass
  #
  # You must implement these methods:
  #
  #   self.find_by_session_id(session_id)
  #   initialize(hash_of_session_id_and_data, options_hash = {})
  #   attr_reader :session_id
  #   attr_accessor :data
  #   save
  #   destroy
  #
  # The example SqlBypass class is a generic SQL session store. You may
  # use it as a basis for high-performance database-specific stores.
  class SessionStore < ActionDispatch::Session::AbstractStore
    module ClassMethods # :nodoc:
      def marshal(data)
        ::Base64.encode64(Marshal.dump(data)) if data
      end

      def unmarshal(data)
        Marshal.load(::Base64.decode64(data)) if data
      end

      def drop_table!
        connection.schema_cache.clear_table_cache!(table_name)
        connection.drop_table table_name
      end

      def create_table!
        connection.schema_cache.clear_table_cache!(table_name)
        connection.create_table(table_name) do |t|
          t.string session_id_column, :limit => 255
          t.text data_column_name
        end
        connection.add_index table_name, session_id_column, :unique => true
      end
    end

    # The default Active Record class.
    class Session < ActiveRecord::Base
      extend ClassMethods

      ##
      # :singleton-method:
      # Customizable data column name. Defaults to 'data'.
      cattr_accessor :data_column_name
      self.data_column_name = 'data'

      attr_accessible :session_id, :data, :marshaled_data

      before_save :marshal_data!
      before_save :raise_on_session_data_overflow!

      class << self
        def data_column_size_limit
          @data_column_size_limit ||= columns_hash[data_column_name].limit
        end

        # Hook to set up sessid compatibility.
        def find_by_session_id(session_id)
          setup_sessid_compatibility!
          find_by_session_id(session_id)
        end

        private
          def session_id_column
            'session_id'
          end

          # Compatibility with tables using sessid instead of session_id.
          def setup_sessid_compatibility!
            # Reset column info since it may be stale.
            reset_column_information
            if columns_hash['sessid']
              def self.find_by_session_id(*args)
                find_by_sessid(*args)
              end

              define_method(:session_id)  { sessid }
              define_method(:session_id=) { |session_id| self.sessid = session_id }
            else
              class << self; remove_method :find_by_session_id; end

              def self.find_by_session_id(session_id)
                find :first, :conditions => {:session_id=>session_id}
              end
            end
          end
      end

      def initialize(attributes = nil, options = {})
        @data = nil
        super
      end

      # Lazy-unmarshal session state.
      def data
        @data ||= self.class.unmarshal(read_attribute(@@data_column_name)) || {}
      end

      attr_writer :data

      # Has the session been loaded yet?
      def loaded?
        @data
      end

      private
        def marshal_data!
          return false unless loaded?
          write_attribute(@@data_column_name, self.class.marshal(data))
        end

        # Ensures that the data about to be stored in the database is not
        # larger than the data storage column. Raises
        # ActionController::SessionOverflowError.
        def raise_on_session_data_overflow!
          return false unless loaded?
          limit = self.class.data_column_size_limit
          if limit and read_attribute(@@data_column_name).size > limit
            raise ActionController::SessionOverflowError
          end
        end
    end

    # A barebones session store which duck-types with the default session
    # store but bypasses Active Record and issues SQL directly. This is
    # an example session model class meant as a basis for your own classes.
    #
    # The database connection, table name, and session id and data columns
    # are configurable class attributes. Marshaling and unmarshaling
    # are implemented as class methods that you may override. By default,
    # marshaling data is
    #
    #   ::Base64.encode64(Marshal.dump(data))
    #
    # and unmarshaling data is
    #
    #   Marshal.load(::Base64.decode64(data))
    #
    # This marshaling behavior is intended to store the widest range of
    # binary session data in a +text+ column. For higher performance,
    # store in a +blob+ column instead and forgo the Base64 encoding.
    class SqlBypass
      extend ClassMethods

      ##
      # :singleton-method:
      # The table name defaults to 'sessions'.
      cattr_accessor :table_name
      @@table_name = 'sessions'

      ##
      # :singleton-method:
      # The session id field defaults to 'session_id'.
      cattr_accessor :session_id_column
      @@session_id_column = 'session_id'

      ##
      # :singleton-method:
      # The data field defaults to 'data'.
      cattr_accessor :data_column
      @@data_column = 'data'

      class << self
        alias :data_column_name :data_column
        
        # Use the ActiveRecord::Base.connection by default.
        attr_writer :connection
        
        # Use the ActiveRecord::Base.connection_pool by default.
        attr_writer :connection_pool

        def connection
          @connection ||= ActiveRecord::Base.connection
        end

        def connection_pool
          @connection_pool ||= ActiveRecord::Base.connection_pool
        end

        # Look up a session by id and unmarshal its data if found.
        def find_by_session_id(session_id)
          if record = connection.select_one("SELECT * FROM #{@@table_name} WHERE #{@@session_id_column}=#{connection.quote(session_id)}")
            new(:session_id => session_id, :marshaled_data => record['data'])
          end
        end
      end
      
      delegate :connection, :connection=, :connection_pool, :connection_pool=, :to => self

      attr_reader :session_id, :new_record
      alias :new_record? :new_record

      attr_writer :data

      # Look for normal and marshaled data, self.find_by_session_id's way of
      # telling us to postpone unmarshaling until the data is requested.
      # We need to handle a normal data attribute in case of a new record.
      def initialize(attributes)
        @session_id     = attributes[:session_id]
        @data           = attributes[:data]
        @marshaled_data = attributes[:marshaled_data]
        @new_record     = @marshaled_data.nil?
      end

      # Lazy-unmarshal session state.
      def data
        unless @data
          if @marshaled_data
            @data, @marshaled_data = self.class.unmarshal(@marshaled_data) || {}, nil
          else
            @data = {}
          end
        end
        @data
      end

      def loaded?
        @data
      end

      def save
        return false unless loaded?
        marshaled_data = self.class.marshal(data)
        connect        = connection

        if @new_record
          @new_record = false
          connect.update <<-end_sql, 'Create session'
            INSERT INTO #{table_name} (
              #{connect.quote_column_name(session_id_column)},
              #{connect.quote_column_name(data_column)} )
            VALUES (
              #{connect.quote(session_id)},
              #{connect.quote(marshaled_data)} )
          end_sql
        else
          connect.update <<-end_sql, 'Update session'
            UPDATE #{table_name}
            SET #{connect.quote_column_name(data_column)}=#{connect.quote(marshaled_data)}
            WHERE #{connect.quote_column_name(session_id_column)}=#{connect.quote(session_id)}
          end_sql
        end
      end

      def destroy
        return if @new_record

        connect = connection
        connect.delete <<-end_sql, 'Destroy session'
          DELETE FROM #{table_name}
          WHERE #{connect.quote_column_name(session_id_column)}=#{connect.quote(session_id)}
        end_sql
      end
    end

    # The class used for session storage. Defaults to
    # ActiveRecord::SessionStore::Session
    cattr_accessor :session_class
    self.session_class = Session

    SESSION_RECORD_KEY = 'rack.session.record'
    ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY

    private
      def get_session(env, sid)
        Base.silence do
          unless sid and session = @@session_class.find_by_session_id(sid)
            # If the sid was nil or if there is no pre-existing session under the sid,
            # force the generation of a new sid and associate a new session associated with the new sid
            sid = generate_sid
            session = @@session_class.new(:session_id => sid, :data => {})
          end
          env[SESSION_RECORD_KEY] = session
          [sid, session.data]
        end
      end

      def set_session(env, sid, session_data, options)
        Base.silence do
          record = get_session_model(env, sid)
          record.data = session_data
          return false unless record.save

          session_data = record.data
          if session_data && session_data.respond_to?(:each_value)
            session_data.each_value do |obj|
              obj.clear_association_cache if obj.respond_to?(:clear_association_cache)
            end
          end
        end

        sid
      end

      def destroy_session(env, session_id, options)
        if sid = current_session_id(env)
          Base.silence do
            get_session_model(env, sid).destroy
            env[SESSION_RECORD_KEY] = nil
          end
        end

        generate_sid unless options[:drop]
      end

      def get_session_model(env, sid)
        if env[ENV_SESSION_OPTIONS_KEY][:id].nil?
          env[SESSION_RECORD_KEY] = find_session(sid)
        else
          env[SESSION_RECORD_KEY] ||= find_session(sid)
        end
      end

      def find_session(id)
        @@session_class.find_by_session_id(id) ||
          @@session_class.new(:session_id => id, :data => {})
      end
  end
end
