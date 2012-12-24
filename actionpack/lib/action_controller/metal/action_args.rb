module ActionController
  # == Action Controller Arguments
  #
  # You can specify Ruby arguments to your actions, and they
  # will automatically be populated with the same-named
  # parameters from the `params` hash.
  #
  #   class PostsController < ActionController::Base
  #     def index(query)
  #       # query is the same as params[:query]
  #     end
  #   end
  #
  # Action arguments work well with strong parameters. Any
  # arguments specified in your action are automatically
  # `required`, so Rails will automatically return a 400
  # Bad Request if the parameter was not present.
  #
  # You can also specify a list of attributes of the main
  # resource to permit by default.
  #
  #   class PostsController < ActionController::Base
  #     permits :title, :body
  #
  #     def create(post)
  #       # post is params[:post].permit(:title, :body)
  #     end
  #   end
  module ActionArgs
    extend ActiveSupport::Concern

    include ActionController::StrongParameters

    def send_action(method_name, *args, &block)
      return super if args.present?

      parameters = method(method_name).parameters.reject { |type, _| type == :block }

      values, _ = process_parameters(parameters)

      super method_name, *values, &block
    end

    module ClassMethods
      # Specifies a list of attributes of the main parameters hash
      # to be whitelisted.
      #
      #   class PostsController < ApplicationController
      #     permits :title, :body
      #
      #     def create(post)
      #       # post == params[:post].permit(:title, :body)
      #     end
      #   end
      #
      # The attributes apply to the sub-hash in `params` corresponding
      # to the singularized form of the controller name. In this
      # example, since the controller name was `posts`, the attributes
      # apply to `params[:post]`.
      def permits(*attributes)
        @_permitted_attributes = attributes
      end

      attr_reader :_permitted_attributes
    end

    private
      def process_parameters(parameters)
        return if self.class.anonymous?

        model_name = controller_name.singularize.to_sym
        permitted_attributes = self.class._permitted_attributes

        values, keywords = [], {}

        parameters.map do |type, key|
          params.require(key) if type == :req

          if (key == model_name) && permitted_attributes && params[key]
            value = params[key].try(:permit, *permitted_attributes)
          else
            value = params[key]
          end

          if type == :req
            values << value
          elsif type == :key
            keywords[key] = value
          end
        end

        [ values, keywords ]
      end
  end
end
