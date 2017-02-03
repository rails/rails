require "models/topic"

class Reply < Topic
  validate :errors_on_empty_content
  validate :title_is_wrong_create,  on: :create

  validate :check_empty_title
  validate :check_content_mismatch, on: :create
  validate :check_wrong_update,     on: :update

  def check_empty_title
    errors[:title] << "is Empty" unless title && title.size > 0
  end

  def errors_on_empty_content
    errors[:content] << "is Empty" unless content && content.size > 0
  end

  def check_content_mismatch
    if title && content && content == "Mismatch"
      errors[:title] << "is Content Mismatch"
    end
  end

  def title_is_wrong_create
    errors[:title] << "is Wrong Create" if title && title == "Wrong Create"
  end

  def check_wrong_update
    errors[:title] << "is Wrong Update" if title && title == "Wrong Update"
  end
end
