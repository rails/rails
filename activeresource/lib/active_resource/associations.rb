module ActiveResource::Associations

  module Builder
    autoload :Association, 'active_resource/associations/builder/association'
    autoload :HasMany,     'active_resource/associations/builder/has_many'
    autoload :HasOne,      'active_resource/associations/builder/has_one'
    autoload :BelongsTo,   'active_resource/associations/builder/belongs_to'
  end



  # Specifies a one-to-many association.
  #
  # === Options
  # [:class_name]
  #   Specify the class name of the association. This class name would
  #   be used for resolving the association class. 
  #
  # ==== Example for [:class_name] - option
  # GET /posts/123.xml delivers following response body:
  #   <post>
  #     <title>ActiveResource now have associations</title>
  #     <content> ... </content>
  #     <comments>
  #       <comment> ... </comment>
  #       <comment> ... </comment>
  #     </comments>
  #   </post>
  # ====
  #
  # <tt>has_many :comments, :class_name => 'myblog/comment'</tt>
  # Would resolve those comments into the <tt>Myblog::Comment</tt> class.
  def has_many(name, options = {})
    Builder::HasMany.build(self, name, options)
  end

  # Specifies a one-to-one association.
  #
  # === Options
  # [:class_name]
  #   Specify the class name of the association. This class name would
  #   be used for resolving the association class. 
  #
  # ==== Example for [:class_name] - option
  # GET /posts/123.xml delivers following response body:
  #   <post>
  #     <title>ActiveResource now have associations</title>
  #     <content> ... </content>
  #     <author>
  #       <name>caffeinatedBoys</name>
  #     </author>
  #   </post>
  # ====
  #
  # <tt>has_one :author, :class_name => 'myblog/author'</tt>
  # Would resolve this author into the <tt>Myblog::Author</tt> class.
  def has_one(name, options = {})
    Builder::HasOne.build(self, name, options)
  end

  # Specifies a one-to-one association with another class. This class should only be used
  # if this class contains the foreign key. 
  #
  # Methods will be added for retrieval and query for a single associated object, for which
  # this object holds an id:
  #
  # [association(force_reload = false)]
  #   Returns the associated object. +nil+ is returned if the foreign key is +nil+.
  #   Throws a ActiveResource::ResourceNotFound exception if the foreign key is not +nil+
  #   and the resource is not found.
  # 
  # (+association+ is replaced with the symbol passed as the first argument, so
  # <tt>belongs_to :post</tt> would add among others <tt>post.nil?</tt>.
  #
  # === Example
  #
  # A Comment class declaress <tt>belongs_to :post</tt>, which will add:
  # * <tt>Comment#post</tt> (similar to <tt>Post.find(post_id)</tt>)
  # The declaration can also include an options hash to specialize the behavior of the association.
  #
  # === Options
  # [:class_name]
  #   Specify the class name for the association. Use it only if that name canÄt be inferred from association name.
  #   So <tt>belongs_to :post</tt> will by default be linked to the Post class, but if the real class name is Article,
  #   you'll have to specify it with whis option.
  # [:foreign_key]
  #   Specify the foreign key used for the association. By default this is guessed to be the name
  #   of the association with an "_id" suffix. So a class that defines a <tt>belongs_to :post</tt>
  #   association will use "post_id" as the default <tt>:foreign_key</tt>. Similarly,
  #   <tt>belongs_to :article, :class_name => "Post"</tt> will use a foreign key
  #   of "article_id".
  #
  # Option examples:
  # <tt>belongs_to :customer, :class_name => 'User'</tt>
  # Creates a belongs_to association called customer which is represented through the <tt>User</tt> class.
  #
  # <tt>belongs_to :customer, :foreign_key => 'user_id'</tt>
  # Creates a belongs_to association called customer which would be resolved by the foreign_key <tt>user_id</tt> instead of <tt>customer_id</tt>
  #
  def belongs_to(name, options={})
    Builder::BelongsTo.build(self, name, options)
  end

  # Defines the belongs_to association finder method
  def defines_belongs_to_finder_method(method_name, association_model, finder_key)
    define_method(method_name) do
      ivar_name = :"@#{method_name}"
      instance_variable_defined?(ivar_name) ? instance_variable_get(ivar_name) : instance_variable_set(ivar_name, association_model.find(send(finder_key)))
    end
  end

end
