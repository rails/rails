module Blog
  def self._railtie
    Object.new
  end

  def self.table_name_prefix
    "blog_"
  end

  class Post
    extend ActiveModel::Naming
    include ActiveModel::Validations

    attr_accessor :title, :header, :editor
    validates :title, :presence => true
    validates :header, :presence => true
    validates :editor, :presence => true

  end
end
