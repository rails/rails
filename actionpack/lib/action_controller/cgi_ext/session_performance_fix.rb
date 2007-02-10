# CGI::Session#create_new_id requires 'digest/md5' on every call.  This makes
# sense when spawning processes per request, but is unnecessarily expensive
# when serving requests from a long-lived process.
#
# http://railsexpress.de/blog/articles/2005/11/22/speeding-up-the-creation-of-new-sessions
require 'cgi/session'
require 'digest/md5'

class CGI
  class Session #:nodoc:
    private
      # Create a new session id.
      #
      # The session id is an MD5 hash based upon the time,
      # a random number, and a constant string.  This routine
      # is used internally for automatically generated
      # session ids.
      def create_new_id
        md5 = Digest::MD5::new
        now = Time::now
        md5.update(now.to_s)
        md5.update(String(now.usec))
        md5.update(String(rand(0)))
        md5.update(String($$))
        md5.update('foobar')
        @new_session = true
        md5.hexdigest
      end
  end
end
