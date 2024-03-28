# This migration comes from action_text (originally 20231225183112)
# frozen_string_literal: true

class AddEditorNameToActionTextRichTexts < ActiveRecord::Migration[6.0]
  def up
    return unless table_exists?(:action_text_rich_texts)

    unless column_exists?(:action_text_rich_texts, :editor_name)
      add_column :action_text_rich_texts, :editor_name, :string, null: true

      ActionText::RichText.unscoped.update_all(editor_name: :trix)

      change_column_null :action_text_rich_texts, :editor_name, false
    end
  end

  def down
    return unless table_exists?(:action_text_rich_texts)

    remove_column :action_text_rich_texts, :editor_name
  end
end
