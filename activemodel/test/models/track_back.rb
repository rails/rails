class Post
  class TrackBack
    def to_model
      NamedTrackBack.new
    end
  end

  class NamedTrackBack
    include ActiveModel::Naming
  end
end
