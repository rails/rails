module ActiveResource::Associations

  module Builder
    autoload :Association, 'active_resource/associations/builder/association'
    autoload :HasMany,     'active_resource/associations/builder/has_many'
    autoload :HasOne,      'active_resource/associations/builder/has_one'
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
  # Would resolve this comments into the <tt>Myblog::Comment</tt> class.
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

end
