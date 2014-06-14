module ActionDispatch
  module Routing
    class Mapper
      module DSL
        module Scoping
          # === Parameter Restriction
          # Allows you to constrain the nested routes based on a set of rules.
          # For instance, in order to change the routes to allow for a dot character in the +id+ parameter:
          #
          #   constraints(id: /\d+\.\d+/) do
          #     resources :posts
          #   end
          #
          # Now routes such as +/posts/1+ will no longer be valid, but +/posts/1.1+ will be.
          # The +id+ parameter must match the constraint passed in for this example.
          #
          # You may use this to also restrict other parameters:
          #
          #   resources :posts do
          #     constraints(post_id: /\d+\.\d+/) do
          #       resources :comments
          #     end
          #   end
          #
          # === Restricting based on IP
          #
          # Routes can also be constrained to an IP or a certain range of IP addresses:
          #
          #   constraints(ip: /192\.168\.\d+\.\d+/) do
          #     resources :posts
          #   end
          #
          # Any user connecting from the 192.168.* range will be able to see this resource,
          # where as any user connecting outside of this range will be told there is no such route.
          #
          # === Dynamic request matching
          #
          # Requests to routes can be constrained based on specific criteria:
          #
          #    constraints(lambda { |req| req.env["HTTP_USER_AGENT"] =~ /iPhone/ }) do
          #      resources :iphones
          #    end
          #
          # You are able to move this logic out into a class if it is too complex for routes.
          # This class must have a +matches?+ method defined on it which either returns +true+
          # if the user should be given access to that route, or +false+ if the user should not.
          #
          #    class Iphone
          #      def self.matches?(request)
          #        request.env["HTTP_USER_AGENT"] =~ /iPhone/
          #      end
          #    end
          #
          # An expected place for this code would be +lib/constraints+.
          #
          # This class is then used like this:
          #
          #    constraints(Iphone) do
          #      resources :iphones
          #    end
          def constraints(constraints = {})
            scope(:constraints => constraints) { yield }
          end
        end
      end
    end
  end
end
