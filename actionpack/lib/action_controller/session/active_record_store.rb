begin

require 'active_record'
require 'cgi'
require 'cgi/session'
require 'base64'

# Contributed by Tim Bates
class CGI
  class Session
    # Active Record database-based session storage class.
    #
    # Implements session storage in a database using the ActiveRecord ORM library. Assumes that the database
    # has a table called +sessions+ with columns +id+ (numeric, primary key), +sessid+ and +data+ (text).
    # The session data is stored in the +data+ column in the binary Marshal format; the user is responsible for ensuring that
    # only data that can be Marshaled is stored in the session.
    #
    # Adding +created_at+ or +updated_at+ datetime columns to the sessions table will enable stamping of the data, which can
    # be used to clear out old sessions.
    #
    # It's highly recommended to have an index on the sessid column to improve performance.
    class ActiveRecordStore
      # The ActiveRecord class which corresponds to the database table.
      class Session < ActiveRecord::Base
      end

      # Create a new ActiveRecordStore instance. This constructor is used internally by CGI::Session.
      # The user does not generally need to call it directly.
      #
      # +session+ is the session for which this instance is being created.
      #
      # +option+ is currently ignored as no options are recognized.
      #
      # This session's ActiveRecord database row will be created if it does not exist, or opened if it does.
      def initialize(session, option=nil)
        ActiveRecord::Base.silence do
          @session = Session.find_by_sessid(session.session_id) || Session.new("sessid" => session.session_id, "data" => marshalize({}))
          @data    = unmarshalize(@session.data)
        end
      end

      # Update and close the session's ActiveRecord object.
      def close
        return unless @session
        update
        @session = nil
      end

      # Close and destroy the session's ActiveRecord object.
      def delete
        return unless @session
        @session.destroy
        @session = nil
      end

      # Restore session state from the session's ActiveRecord object.
      def restore
        return unless @session
        @data = unmarshalize(@session.data)
      end

      # Save session state in the session's ActiveRecord object.
      def update
        return unless @session
        ActiveRecord::Base.silence { @session.update_attribute "data", marshalize(@data) }
      end

      private
        def unmarshalize(data)
          Marshal.load(Base64.decode64(data))
        end

        def marshalize(data)
          Base64.encode64(Marshal.dump(data))
        end
    end #ActiveRecordStore
  end #Session
end #CGI

rescue LoadError
  # Couldn't load Active Record, so don't make this store available
end
