module Blog
  def self.use_relative_model_naming?
    true
  end

  class Post
    extend ActiveModel::Naming
  end
end
