# cgi/session/memcached.rb - persistent storage of marshalled session data
#
# == Overview
#
# This file provides the CGI::Session::MemCache class, which builds
# persistence of storage data on top of the MemCache library.  See
# cgi/session.rb for more details on session storage managers.
#

begin
  require 'cgi/session'
  require 'memcache'

  class CGI
    class Session
      # MemCache-based session storage class.
      #
      # This builds upon the top-level MemCache class provided by the
      # library file memcache.rb.  Session data is marshalled and stored
      # in a memcached cache.
      class MemCacheStore
        def check_id(id) #:nodoc:#
          /[^0-9a-zA-Z]+/ =~ id.to_s ? false : true
        end

        # Create a new CGI::Session::MemCache instance
        #
        # This constructor is used internally by CGI::Session.  The
        # user does not generally need to call it directly.
        #
        # +session+ is the session for which this instance is being
        # created.  The session id must only contain alphanumeric
        # characters; automatically generated session ids observe
        # this requirement.
        #
        # +option+ is a hash of options for the initializer.  The
        # following options are recognized:
        #
        # cache::  an instance of a MemCache client to use as the
        #      session cache.
        #
        # This session's memcache entry will be created if it does
        # not exist, or retrieved if it does.
        def initialize(session, options = {})
          id = session.session_id
          unless check_id(id)
            raise ArgumentError, "session_id '%s' is invalid" % id
  	      end
          @cache = options['cache'] || MemCache.new('localhost')
  	      @session_key = "session:#{id}"
  	      @hash = {}
        end

        # Restore session state from the session's memcache entry.
        #
        # Returns the session state as a hash.
        def restore
          begin
            @hash = @cache[@session_key]
          rescue
            # Ignore session get failures.
          end
          @hash = {} unless @hash
  	      @hash
        end

        # Save session state to the session's memcache entry.
        def update
          begin
            @cache[@session_key] = @hash
          rescue
            # Ignore session update failures.
          end
        end
      
        # Update and close the session's memcache entry.
        def close
          update
        end

        # Delete the session's memcache entry.
        def delete
          begin
            @cache.delete(@session_key)
          rescue
            # Ignore session delete failures.
          end
  	      @hash = {}
        end
      end
    end
  end
rescue LoadError
  # MemCache wasn't available so neither can the store be
end
