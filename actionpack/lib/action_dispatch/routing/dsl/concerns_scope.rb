module ActionDispatch
  module Routing
    class Mapper
      module DSL
        # Routing Concerns allow you to declare common routes that can be reused
        # inside others resources and routes.
        #
        #   concern :commentable do
        #     resources :comments
        #   end
        #
        #   concern :image_attachable do
        #     resources :images, only: :index
        #   end
        #
        # These concerns are used in Resources routing:
        #
        #   resources :messages, concerns: [:commentable, :image_attachable]
        #
        # or in a scope or namespace:
        #
        #   namespace :posts do
        #     concerns :commentable
        #   end
        module Concerns
          # Define a routing concern using a name.
          #
          # Concerns may be defined inline, using a block, or handled by
          # another object, by passing that object as the second parameter.
          #
          # The concern object, if supplied, should respond to <tt>call</tt>,
          # which will receive two parameters:
          #
          #   * The current mapper
          #   * A hash of options which the concern object may use
          #
          # Options may also be used by concerns defined in a block by accepting
          # a block parameter. So, using a block, you might do something as
          # simple as limit the actions available on certain resources, passing
          # standard resource options through the concern:
          #
          #   concern :commentable do |options|
          #     resources :comments, options
          #   end
          #
          #   resources :posts, concerns: :commentable
          #   resources :archived_posts do
          #     # Don't allow comments on archived posts
          #     concerns :commentable, only: [:index, :show]
          #   end
          #
          # Or, using a callable object, you might implement something more
          # specific to your application, which would be out of place in your
          # routes file.
          #
          #   # purchasable.rb
          #   class Purchasable
          #     def initialize(defaults = {})
          #       @defaults = defaults
          #     end
          #
          #     def call(mapper, options = {})
          #       options = @defaults.merge(options)
          #       mapper.resources :purchases
          #       mapper.resources :receipts
          #       mapper.resources :returns if options[:returnable]
          #     end
          #   end
          #
          #   # routes.rb
          #   concern :purchasable, Purchasable.new(returnable: true)
          #
          #   resources :toys, concerns: :purchasable
          #   resources :electronics, concerns: :purchasable
          #   resources :pets do
          #     concerns :purchasable, returnable: false
          #   end
          #
          # Any routing helpers can be used inside a concern. If using a
          # callable, they're accessible from the Mapper that's passed to
          # <tt>call</tt>.
          def concern(name, callable = nil, &block)
            callable ||= lambda { |mapper, options| mapper.instance_exec(options, &block) }
            @concerns[name] = callable
          end

          # Use the named concerns
          #
          #   resources :posts do
          #     concerns :commentable
          #   end
          #
          # concerns also work in any routes helper that you want to use:
          #
          #   namespace :posts do
          #     concerns :commentable
          #   end
          def concerns(*args)
            options = args.extract_options!
            args.flatten.each do |name|
              if concern = @concerns[name]
                concern.call(self, options)
              else
                raise ArgumentError, "No concern named #{name} was found!"
              end
            end
          end
        end
      end
    end
  end
end
