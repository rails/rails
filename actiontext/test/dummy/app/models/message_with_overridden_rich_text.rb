class MessageWithOverriddenRichText < ApplicationRecord
  self.table_name = Message.table_name

  has_rich_text :content
  has_rich_text :note
  has_rich_text :summary, store_if_blank: false

  def content
    super.tap { |rich_text| rich_text.body ||= "<h1>Default</h1>" }
  end

  def content?
    !super
  end

  def note=(value)
    super("<h1>#{value}</h1>")
  end

  def summary=(value)
    super(value.presence && "<h1>#{value}</h1>")
  end
end
