# frozen_string_literal: true

module ActionText
  # Fixtures are a way of organizing data that you want to test against; in
  # short, sample data.
  #
  # To learn more about fixtures, read the ActiveRecord::FixtureSet documentation.
  #
  # === YAML
  #
  # Like other Active Record-backed models, ActionText::RichText records inherit
  # from ActiveRecord::Base instances and can therefore be populated by
  # fixtures.
  #
  # Consider an <tt>Article</tt> class:
  #
  #   class Article < ApplicationRecord
  #     has_rich_text :content
  #   end
  #
  # To declare fixture data for the related <tt>content</tt>, first declare fixture
  # data for <tt>Article</tt> instances in <tt>test/fixtures/articles.yml</tt>:
  #
  #   first:
  #     title: An Article
  #
  # Then declare the ActionText::RichText fixture data in
  # <tt>test/fixtures/action_text/rich_texts.yml</tt>, making sure to declare
  # each entry's <tt>record:</tt> key as a polymorphic relationship:
  #
  #   first:
  #     record: first (Article)
  #     name: content
  #     body: <div>Hello, world.</div>
  #
  # When processed, Active Record will insert database records for each fixture
  # entry and will ensure the Action Text relationship is intact.
  class FixtureSet
    # Fixtures support Action Text attachments as part of their <tt>body</tt>
    # HTML.
    #
    # === Examples
    #
    # For example, consider a second <tt>Article</tt> fixture declared in
    # <tt>test/fixtures/articles.yml</tt>:
    #
    #   second:
    #     title: Another Article
    #
    # You can attach a mention of <tt>articles(:first)</tt> to <tt>second</tt>'s
    # <tt>content</tt> by embedding a call to <tt>ActionText::FixtureSet.attachment</tt>
    # in the <tt>body:</tt> value in <tt>test/fixtures/action_text/rich_texts.yml</tt>:
    #
    #   second:
    #     record: second (Article)
    #     name: content
    #     body: <div>Hello, <%= ActionText::FixtureSet.attachment("articles", :first) %></div>
    #
    def self.attachment(fixture_set_name, label, column_type: :integer)
      signed_global_id = ActiveRecord::FixtureSet.signed_global_id fixture_set_name, label,
        column_type: column_type, for: ActionText::Attachable::LOCATOR_NAME

      %(<action-text-attachment sgid="#{signed_global_id}"></action-text-attachment>)
    end
  end
end
