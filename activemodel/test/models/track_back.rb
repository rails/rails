class Post
  class TrackBack
    def to_model
      NamedTrackBack.new(self)
    end
  end

  class NamedTrackBack
    extend ActiveModel::Naming
  end
end