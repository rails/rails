require 'cgi'
require 'cgi/session'
require 'drb'
 
class CGI #:nodoc:all
  class Session
    class DRbStore
      @@session_data = DRbObject.new(nil, 'druby://localhost:9192')
 
      def initialize(session, option=nil)
        @session_id = session.session_id
      end
 
      def restore
        @h = @@session_data[@session_id] || {}
      end
 
      def update
        @@session_data[@session_id] = @h
      end
 
      def close
        update
      end
 
      def delete
        @@session_data.delete(@session_id)
      end
      
      def data
        @@session_data[@session_id]
      end
    end
  end
end
