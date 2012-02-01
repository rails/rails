module ActionView
  module Helpers
    module FormCollectionsHelper
      # Returns radio button tags for the collection of existing return values of +method+ for
      # +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are methods to be called on each member
      # of +collection+. The return values are used as the +value+ attribute and contents of each
      # radio button tag, respectively.
      #
      # Example object structure for use with this method:
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #   end
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #   collection_radio_buttons(:post, :author_id, Author.all, :id, :name_with_initial)
      #
      # If <tt>@post.author_id</tt> is already <tt>1</tt>, this would return:
      #   <input id="post_author_id_1" name="post[author_id]" type="radio" value="1" checked="checked" />
      #   <label class="collection_radio_buttons" for="post_author_id_1">D. Heinemeier Hansson</label>
      #   <input id="post_author_id_2" name="post[author_id]" type="radio" value="2" />
      #   <label class="collection_radio_buttons" for="post_author_id_2">D. Thomas</label>
      #   <input id="post_author_id_3" name="post[author_id]" type="radio" value="3" />
      #   <label class="collection_radio_buttons" for="post_author_id_3">M. Clark</label>
      def collection_radio_buttons(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionRadioButtons.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end

      # Returns check box tags for the collection of existing return values of +method+ # for
      # +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are methods to be called on each member
      # of +collection+. The return values are used as the +value+ attribute and contents of each
      # check box tag, respectively.
      #
      # Example object structure for use with this method:
      #   class Post < ActiveRecord::Base
      #     has_and_belongs_to :author
      #   end
      #   class Author < ActiveRecord::Base
      #     has_and_belongs_to :posts
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #   collection_check_boxes(:post, :author_ids, Author.all, :id, :name_with_initial)
      #
      # If <tt>@post.author_ids</tt> is already <tt>[1]</tt>, this would return:
      #   <input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="1" checked="checked" />
      #   <label class="collection_check_boxes" for="post_author_ids_1">D. Heinemeier Hansson</label>
      #   <input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="2" />
      #   <label class="collection_check_boxes" for="post_author_ids_1">D. Thomas</label>
      #   <input id="post_author_ids_3" name="post[author_ids][]" type="checkbox" value="3" />
      #   <label class="collection_check_boxes" for="post_author_ids_3">M. Clark</label>
      #   <input name="post[author_ids][]" type="hidden" value="" />
      def collection_check_boxes(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionCheckBoxes.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end
    end

    class FormBuilder
      def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_radio_buttons(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end

      def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_check_boxes(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end
    end
  end
end
