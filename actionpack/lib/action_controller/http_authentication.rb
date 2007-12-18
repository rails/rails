module ActionController
  module HttpAuthentication
    # Makes it dead easy to do HTTP Basic authentication.
    # 
    # Simple Basic example:
    # 
    #   class PostsController < ApplicationController
    #     USER_NAME, PASSWORD = "dhh", "secret"
    #   
    #     before_filter :authenticate, :except => [ :index ]
    #   
    #     def index
    #       render :text => "Everyone can see me!"
    #     end
    #   
    #     def edit
    #       render :text => "I'm only accessible if you know the password"
    #     end
    #   
    #     private
    #       def authenticate
    #         authenticate_or_request_with_http_basic do |user_name, password| 
    #           user_name == USER_NAME && password == PASSWORD
    #         end
    #       end
    #   end
    # 
    # 
    # Here is a more advanced Basic example where only Atom feeds and the XML API is protected by HTTP authentication, 
    # the regular HTML interface is protected by a session approach:
    # 
    #   class ApplicationController < ActionController::Base
    #     before_filter :set_account, :authenticate
    #   
    #     protected
    #       def set_account
    #         @account = Account.find_by_url_name(request.subdomains.first)
    #       end
    #   
    #       def authenticate
    #         case request.format
    #         when Mime::XML, Mime::ATOM
    #           if user = authenticate_with_http_basic { |u, p| @account.users.authenticate(u, p) }
    #             @current_user = user
    #           else
    #             request_http_basic_authentication
    #           end
    #         else
    #           if session_authenticated?
    #             @current_user = @account.users.find(session[:authenticated][:user_id])
    #           else
    #             redirect_to(login_url) and return false
    #           end
    #         end
    #       end
    #   end
    # 
    # 
    # In your integration tests, you can do something like this:
    # 
    #   def test_access_granted_from_xml
    #     get(
    #       "/notes/1.xml", nil, 
    #       :authorization => ActionController::HttpAuthentication::Basic.encode_credentials(users(:dhh).name, users(:dhh).password)
    #     )
    # 
    #     assert_equal 200, status
    #   end
    #  
    #  
    # On shared hosts, Apache sometimes doesn't pass authentication headers to
    # FCGI instances. If your environment matches this description and you cannot
    # authenticate, try this rule in public/.htaccess (replace the plain one):
    # 
    #   RewriteRule ^(.*)$ dispatch.fcgi [E=X-HTTP_AUTHORIZATION:%{HTTP:Authorization},QSA,L]
    module Basic
      extend self

      module ControllerMethods
        def authenticate_or_request_with_http_basic(realm = "Application", &login_procedure)
          authenticate_with_http_basic(&login_procedure) || request_http_basic_authentication(realm)
        end

        def authenticate_with_http_basic(&login_procedure)
          HttpAuthentication::Basic.authenticate(self, &login_procedure)
        end

        def request_http_basic_authentication(realm = "Application")
          HttpAuthentication::Basic.authentication_request(self, realm)
        end
      end

      def authenticate(controller, &login_procedure)
        unless authorization(controller.request).blank?
          login_procedure.call(*user_name_and_password(controller.request))
        end
      end

      def user_name_and_password(request)
        decode_credentials(request).split(/:/, 2)
      end
  
      def authorization(request)
        request.env['HTTP_AUTHORIZATION']   ||
        request.env['X-HTTP_AUTHORIZATION'] ||
        request.env['X_HTTP_AUTHORIZATION'] ||
        request.env['REDIRECT_X_HTTP_AUTHORIZATION']
      end
    
      def decode_credentials(request)
        ActiveSupport::Base64.decode64(authorization(request).split.last || '')
      end

      def encode_credentials(user_name, password)
        "Basic #{ActiveSupport::Base64.encode64("#{user_name}:#{password}")}"
      end

      def authentication_request(controller, realm)
        controller.headers["WWW-Authenticate"] = %(Basic realm="#{realm.gsub(/"/, "")}")
        controller.send! :render, :text => "HTTP Basic: Access denied.\n", :status => :unauthorized
      end
    end
  end
end
