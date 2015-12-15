module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected
      def find_verified_user
        if current_user = authenticate_with_cookies
          current_user
        else
          reject_unauthorized_connection
        end
      end

      def authenticate_with_cookies
        # User.find(cookies.signed[:user_id])
      end
  end
end
