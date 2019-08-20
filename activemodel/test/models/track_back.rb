# frozen_string_literal: true

class Post
  class TrackBack
    def to_model
      NamedTrackBack.new
    end
  end

  class NamedTrackBack
    extend ActiveModel::Naming
  end
end
