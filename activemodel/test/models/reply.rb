require 'models/topic'

class Reply < Topic
  validate :errors_on_empty_content
  validate_on_create :title_is_wrong_create

  attr_accessible :title, :author_name, :author_email_address, :written_on, :content, :last_read

  def validate
    errors[:title] << "Empty" unless attribute_present?("title")
  end

  def errors_on_empty_content
    errors[:content] << "Empty" unless attribute_present?("content")
  end

  def validate_on_create
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors[:title] << "is Content Mismatch"
    end
  end

  def title_is_wrong_create
    errors[:title] << "is Wrong Create" if attribute_present?("title") && title == "Wrong Create"
  end

  def validate_on_update
    errors[:title] << "is Wrong Update" if attribute_present?("title") && title == "Wrong Update"
  end
end
