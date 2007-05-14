module ActionController  
  # The record identifier encapsulates a number of naming conventions for dealing with records, like Active Records or 
  # Active Resources or pretty much any other model type that has an id. These patterns are then used to try elevate
  # the view actions to a higher logical level. Example:
  #
  #   # routes
  #   map.resources :posts
  #
  #   # view
  #   <% div_for(post) do %>     <div id="post_45" class="post">
  #     <%= post.body %>           What a wonderful world!
  #   <% end %>                  </div>
  #
  #   # controller
  #   def destroy
  #     post = Post.find(params[:id])
  #     post.destroy
  #
  #     respond_to do |format|
  #       format.html { redirect_to(post) } # Calls polymorphic_url(post) which in turn calls post_url(post)
  #       format.js do
  #         # Calls: new Effect.fade('post_45');
  #         render(:update) { |page| page[post].visual_effect(:fade) }
  #       end
  #     end
  #   end
  #
  # As the example above shows, you can stop caring to a large extend what the actual id of the post is. You just know
  # that one is being assigned and that the subsequent calls in redirect_to and the RJS expect that same naming 
  # convention and allows you to write less code if you follow it.
  module RecordIdentifier
    extend self

    # Returns plural/singular for a record or class. Example:
    #
    #   partial_path(post)   # => "posts/post"
    #   partial_path(Person) # => "people/person"
    def partial_path(record_or_class)
      klass = class_from_record_or_class(record_or_class)
      "#{klass.name.tableize}/#{klass.name.demodulize.underscore}"
    end

    # The DOM class convention is to use the singular form of an object or class. Examples:
    #
    #   dom_class(post)   # => "post"
    #   dom_class(Person) # => "person"
    #
    # If you need to address multiple instances of the same class in the same view, you can prefix the dom_class:
    #
    #   dom_class(post, :edit)   # => "edit_post"
    #   dom_class(Person, :edit) # => "edit_person"
    def dom_class(record_or_class, prefix = nil)
      [ prefix, singular_class_name(record_or_class) ].compact * '_'
    end

    # The DOM class convention is to use the singular form of an object or class with the id following an underscore. 
    # If no id is found, prefix with "new_" instead. Examples:
    #
    #   dom_class(Post.new(:id => 45)) # => "post_45"
    #   dom_class(Post.new)            # => "new_post"
    #
    # If you need to address multiple instances of the same class in the same view, you can prefix the dom_id:
    #
    #   dom_class(Post.new(:id => 45), :edit) # => "edit_post_45"
    def dom_id(record, prefix = nil) 
      prefix ||= 'new' unless record.id
      [ prefix, singular_class_name(record), record.id ].compact * '_'
    end

    # Returns the plural class name of a record or class. Examples:
    #
    #   plural_class_name(post)             # => "posts"
    #   plural_class_name(Highrise::Person) # => "highrise_people"
    def plural_class_name(record_or_class)
      singular_class_name(record_or_class).pluralize
    end

    # Returns the singular class name of a record or class. Examples:
    #
    #   singular_class_name(post)             # => "post"
    #   singular_class_name(Highrise::Person) # => "highrise_person"
    def singular_class_name(record_or_class)
      class_from_record_or_class(record_or_class).name.underscore.tr('/', '_')
    end

    private
      def class_from_record_or_class(record_or_class)
        record_or_class.is_a?(Class) ? record_or_class : record_or_class.class
      end
  end
end