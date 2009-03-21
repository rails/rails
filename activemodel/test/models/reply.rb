require 'models/topic'

class Reply < Topic
  validate :errors_on_empty_content
  validate_on_create :title_is_wrong_create

  validate :check_empty_title
  validate_on_create :check_content_mismatch
  validate_on_update :check_wrong_update

  attr_accessible :title, :author_name, :author_email_address, :written_on, :content, :last_read

  def check_empty_title
    errors[:title] << "Empty" unless attribute_present?("title")
  end

  def errors_on_empty_content
    errors[:content] << "Empty" unless attribute_present?("content")
  end

  def check_content_mismatch
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors[:title] << "is Content Mismatch"
    end
  end

  def title_is_wrong_create
    errors[:title] << "is Wrong Create" if attribute_present?("title") && title == "Wrong Create"
  end

  def check_wrong_update
    errors[:title] << "is Wrong Update" if attribute_present?("title") && title == "Wrong Update"
  end
end
