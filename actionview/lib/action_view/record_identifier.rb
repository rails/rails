# frozen_string_literal: true

require "active_support/core_ext/module"
require "action_view/model_naming"

module ActionView
  # RecordIdentifier encapsulates methods used by various ActionView helpers
  # to associate records with DOM elements.
  #
  # Consider for example the following code that form of post:
  #
  #   <%= form_for(post) do |f| %>
  #     <%= f.text_field :body %>
  #   <% end %>
  #
  # When +post+ is a new, unsaved ActiveRecord::Base instance, the resulting HTML
  # is:
  #
  #    <form class="new_post" id="new_post" action="/posts" accept-charset="UTF-8" method="post">
  #      <input type="text" name="post[body]" id="post_body" />
  #    </form>
  #
  # When +post+ is a persisted ActiveRecord::Base instance, the resulting HTML
  # is:
  #
  #   <form class="edit_post" id="edit_post_42" action="/posts/42" accept-charset="UTF-8" method="post">
  #     <input type="text" value="What a wonderful world!" name="post[body]" id="post_body" />
  #   </form>
  #
  # In both cases, the +id+ and +class+ of the wrapping DOM element are
  # automatically generated, following naming conventions encapsulated by the
  # RecordIdentifier methods #dom_id and #dom_class:
  #
  #   dom_id(Post.new)         # => "new_post"
  #   dom_class(Post.new)      # => "post"
  #   dom_id(Post.find 42)     # => "post_42"
  #   dom_class(Post.find 42)  # => "post"
  #
  # Note that these methods do not strictly require +Post+ to be a subclass of
  # ActiveRecord::Base.
  # Any +Post+ class will work as long as its instances respond to +to_key+
  # and +model_name+, given that +model_name+ responds to +param_key+.
  # For instance:
  #
  #   class Post
  #     attr_accessor :to_key
  #
  #     def model_name
  #       OpenStruct.new param_key: 'post'
  #     end
  #
  #     def self.find(id)
  #       new.tap { |post| post.to_key = [id] }
  #     end
  #   end
  module RecordIdentifier
    extend self
    extend ModelNaming

    include ModelNaming

    JOIN = "_"
    NEW = "new"

    # The DOM class convention is to use the singular form of an object or class.
    #
    #   dom_class(post)   # => "post"
    #   dom_class(Person) # => "person"
    #
    # If you need to address multiple instances of the same class in the same view, you can prefix the dom_class:
    #
    #   dom_class(post, :edit)   # => "edit_post"
    #   dom_class(Person, :edit) # => "edit_person"
    def dom_class(record_or_class, prefix = nil)
      singular = model_name_from_record_or_class(record_or_class).param_key
      prefix ? "#{prefix}#{JOIN}#{singular}" : singular
    end

    # The DOM id convention is to use the singular form of an object or class with the id following an underscore.
    # If no id is found, prefix with "new_" instead.
    #
    #   dom_id(Post.find(45))       # => "post_45"
    #   dom_id(Post.new)            # => "new_post"
    #
    # If you need to address multiple instances of the same class in the same view, you can prefix the dom_id:
    #
    #   dom_id(Post.find(45), :edit) # => "edit_post_45"
    #   dom_id(Post.new, :custom)    # => "custom_post"
    def dom_id(record, prefix = nil)
      if record_id = record_key_for_dom_id(record)
        "#{dom_class(record, prefix)}#{JOIN}#{record_id}"
      else
        dom_class(record, prefix || NEW)
      end
    end

  private
    # Returns a string representation of the key attribute(s) that is suitable for use in an HTML DOM id.
    # This can be overwritten to customize the default generated string representation if desired.
    # If you need to read back a key from a dom_id in order to query for the underlying database record,
    # you should write a helper like 'person_record_from_dom_id' that will extract the key either based
    # on the default implementation (which just joins all key attributes with '_') or on your own
    # overwritten version of the method. By default, this implementation passes the key string through a
    # method that replaces all characters that are invalid inside DOM ids, with valid ones. You need to
    # make sure yourself that your dom ids are valid, in case you override this method.
    def record_key_for_dom_id(record) # :doc:
      key = convert_to_model(record).to_key
      key ? key.join(JOIN) : key
    end
  end
end
