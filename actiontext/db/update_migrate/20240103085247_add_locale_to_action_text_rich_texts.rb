# frozen_string_literal: true

class AddLocaleToActionTextRichTexts < ActiveRecord::Migration[6.0]
  def change
    return unless table_exists?(:action_text_rich_texts)

    add_column :action_text_rich_texts, :locale, :string, null: true

    if (locale = I18n.locale)
      ActionText::RichText.unscoped.update_all(locale: locale)
    end

    change_column_null :action_text_rich_texts, :locale, false
  end
end
