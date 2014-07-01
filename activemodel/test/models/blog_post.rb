module Blog
  def self.use_relative_model_naming?
    true
  end

  class Post
    include ActiveModel::Naming
  end
end
