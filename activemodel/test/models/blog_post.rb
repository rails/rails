module Blog
  def self._railtie
    Object.new
  end

  def self.table_name_prefix
    "blog_"
  end

  class Post
    extend ActiveModel::Naming
  end
end
