begin

require 'active_record'
require 'cgi'
require 'cgi/session'

# Contributed by Tim Bates
class CGI
  class Session
    # ActiveRecord database based session storage class.
    #
    # Implements session storage in a database using the ActiveRecord ORM library. Assumes that the database
    # has a table called +sessions+ with columns +id+ (numeric, primary key), +sessid+ and +data+ (text).
    # The session data is stored in the +data+ column in YAML format; the user is responsible for ensuring that
    # only data that can be YAMLized is stored in the session.
    class ActiveRecordStore
      # The ActiveRecord class which corresponds to the database table.
      class Session < ActiveRecord::Base
        serialize :data
        # Isn't this class definition beautiful?
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
        @session = Session.find_first(["sessid = '%s'", session.session_id])
        if @session
          @data = @session.data
        else
          @session = Session.new("sessid" => session.session_id, "data" => {})
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
        @data = @session.data
      end

      # Save session state in the session's ActiveRecord object.
      def update
        return unless @session
        @session.data = @data
        @session.save
      end
    end #ActiveRecordStore
  end #Session
end #CGI

rescue LoadError
  # Couldn't load Active Record, so don't make this store available
end