require 'cgi'
require 'cgi/session'
require 'digest/md5'
require 'base64'

class CGI
  class Session
    # A session store backed by an Active Record class.
    #
    # A default class is provided, but any object duck-typing to an Active
    # Record +Session+ class with text +session_id+ and +data+ attributes
    # may be used as the backing store.
    #
    # The default assumes a +sessions+ tables with columns +id+ (numeric
    # primary key), +session_id+ (text), and +data+ (text).  Session data is
    # marshaled to +data+.  +session_id+ should be indexed for speedy lookups.
    #
    # Since the default class is a simple Active Record, you get timestamps
    # for free if you add +created_at+ and +updated_at+ datetime columns to
    # the +sessions+ table, making periodic session expiration a snap.
    #
    # You may provide your own session class, whether a feature-packed
    # Active Record or a bare-metal high-performance SQL store, by setting
    #   +CGI::Session::ActiveRecordStore.session_class = MySessionClass+
    # You must implement these methods:
    #   self.find_by_session_id(session_id)
    #   initialize(hash_of_session_id_and_data)
    #   attr_reader :session_id
    #   attr_accessor :data
    #   save
    #   destroy
    #
    # The fast SqlBypass class is a generic SQL session store.  You may
    # use it as a basis for high-performance database-specific stores.
    class ActiveRecordStore
      # The default Active Record class.
      class Session < ActiveRecord::Base
        before_save   :marshal_data!
        before_update :data_changed?

        class << self
          # Hook to set up sessid compatibility.
          def find_by_session_id(session_id)
            setup_sessid_compatibility!
            find_by_session_id(session_id)
          end

          def marshal(data)     Base64.encode64(Marshal.dump(data)) end
          def unmarshal(data)   Marshal.load(Base64.decode64(data)) end
          def fingerprint(data) Digest::MD5.hexdigest(data)         end

          def create_table!
            connection.execute <<-end_sql
              CREATE TABLE #{table_name} (
                id INTEGER PRIMARY KEY,
                #{connection.quote_column_name('session_id')} TEXT UNIQUE,
                #{connection.quote_column_name('data')} TEXT
              )
            end_sql
          end

          def drop_table!
            connection.execute "DROP TABLE #{table_name}"
          end

          private
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
                def self.find_by_session_id(session_id)
                  find :first, :conditions => ["session_id #{attribute_condition(session_id)}", session_id]
                end
              end
            end
        end

        # Lazy-unmarshal session state.  Take a fingerprint so we can detect
        # whether to save changes later.
        def data
          unless @data
            case @data = read_attribute('data')
              when String
                @fingerprint = self.class.fingerprint(@data)
                @data = self.class.unmarshal(@data)
              when nil
                @data = {}
                @fingerprint = nil
            end
          end
          @data
        end

        private
          def marshal_data!
            write_attribute('data', self.class.marshal(@data || {}))
          end

          def data_changed?
            old_fingerprint, @fingerprint = @fingerprint, self.class.fingerprint(read_attribute('data'))
            old_fingerprint != @fingerprint
          end
      end

      # A barebones session store which duck-types with the default session
      # store but bypasses Active Record and issues SQL directly.
      #
      # The database connection, table name, and session id and data columns
      # are configurable class attributes.  Marshaling and unmarshaling
      # are implemented as class methods that you may override.  By default,
      # marshaling data is +Base64.encode64(Marshal.dump(data))+ and
      # unmarshaling data is +Marshal.load(Base64.decode64(data))+.
      #
      # This marshaling behavior is intended to store the widest range of
      # binary session data in a +text+ column.  For higher performance,
      # store in a +blob+ column instead and forgo the Base64 encoding.
      class SqlBypass
        # Use the ActiveRecord::Base.connection by default.
        cattr_accessor :connection
        def self.connection
          @@connection ||= ActiveRecord::Base.connection
        end

        # The table name defaults to 'sessions'.
        cattr_accessor :table_name
        @@table_name = 'sessions'

        # The session id field defaults to 'session_id'.
        cattr_accessor :session_id_column
        @@session_id_column = 'session_id'

        # The data field defaults to 'data'.
        cattr_accessor :data_column
        @@data_column = 'data'

        class << self
          # Look up a session by id and unmarshal its data if found.
          def find_by_session_id(session_id)
            if record = @@connection.select_one("SELECT * FROM #{@@table_name} WHERE #{@@session_id_column}=#{@@connection.quote(session_id)}")
              new(:session_id => session_id, :marshaled_data => record['data'])
            end
          end

          def marshal(data)     Base64.encode64(Marshal.dump(data)) end
          def unmarshal(data)   Marshal.load(Base64.decode64(data)) end
          def fingerprint(data) Digest::MD5.hexdigest(data)         end

          def create_table!
            @@connection.execute <<-end_sql
              CREATE TABLE #{table_name} (
                id INTEGER PRIMARY KEY,
                #{@@connection.quote_column_name(session_id_column)} TEXT UNIQUE,
                #{@@connection.quote_column_name(data_column)} TEXT
              )
            end_sql
          end

          def drop_table!
            @@connection.execute "DROP TABLE #{table_name}"
          end
        end

        attr_reader :session_id
        attr_writer :data

        # Look for normal and marshaled data, self.find_by_session_id's way of
        # telling us to postpone unmarshaling until the data is requested.
        # We need to handle a normal data attribute in case of a new record.
        def initialize(attributes)
          @session_id, @data, @marshaled_data = attributes[:session_id], attributes[:data], attributes[:marshaled_data]
          @new_record = @marshaled_data.nil?
        end

        def new_record?
          @new_record
        end

        # Lazy-unmarshal session state.  Take a fingerprint so we can detect
        # whether to save changes later.
        def data
          unless @data
            if @marshaled_data
              @fingerprint = self.class.fingerprint(@marshaled_data)
              @data, @marshaled_data = self.class.unmarshal(@marshaled_data), nil
            else
              @data = {}
              @fingerprint = nil
            end
          end
          @data
        end

        def save
          marshaled_data = self.class.marshal(data)
          if @new_record
            @new_record = false
            @@connection.update <<-end_sql, 'Create session'
              INSERT INTO #{@@table_name} (
                #{@@connection.quote_column_name(@@session_id_column)},
                #{@@connection.quote_column_name(@@data_column)} )
              VALUES (
                #{@@connection.quote(session_id)},
                #{@@connection.quote(marshaled_data)} )
            end_sql
          else
            old_fingerprint, @fingerprint = @fingerprint, self.class.fingerprint(marshaled_data)
            if old_fingerprint != @fingerprint
              @@connection.update <<-end_sql, 'Update session'
                UPDATE #{@@table_name}
                SET #{@@connection.quote_column_name(@@data_column)}=#{@@connection.quote(marshaled_data)}
                WHERE #{@@connection.quote_column_name(@@session_id_column)}=#{@@connection.quote(session_id)}
              end_sql
            end
          end
        end

        def destroy
          unless @new_record
            @@connection.delete <<-end_sql, 'Destroy session'
              DELETE FROM #{@@table_name}
              WHERE #{@@connection.quote_column_name(@@session_id_column)}=#{@@connection.quote(session_id)}
            end_sql
          end
        end
      end

      # The class used for session storage.  Defaults to
      # CGI::Session::ActiveRecordStore::Session.
      cattr_accessor :session_class
      @@session_class = Session

      # Find or instantiate a session given a CGI::Session.
      def initialize(session, option = nil)
        session_id = session.session_id
        unless @session = ActiveRecord::Base.silence { @@session_class.find_by_session_id(session_id) }
          unless session.new_session
            raise CGI::Session::NoSession, 'uninitialized session'
          end
          @session = @@session_class.new(:session_id => session_id, :data => {})
        end
      end

      # Restore session state.  The session model handles unmarshaling.
      def restore
        if @session
          @session.data
        end
      end

      # Save session store.
      def update
        if @session
          ActiveRecord::Base.silence { @session.save }
        end
      end

      # Save and close the session store.
      def close
        if @session
          update
          @session = nil
        end
      end

      # Delete and close the session store.
      def delete
        if @session
          ActiveRecord::Base.silence { @session.destroy }
          @session = nil
        end
      end
    end

  end
end
