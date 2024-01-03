# frozen_string_literal: true

require "test_helper"

class ActionText::RichTextTest < ActiveSupport::TestCase
  test "defaults #locale to the I18n.locale after initialization" do
    assert_equal "en", ActionText::RichText.new.locale

    I18n.with_locale "es" do
      assert_equal "es", ActionText::RichText.new.locale
    end
  end

  test "does not override existing #locale after initialization" do
    spanish = ActionText::RichText.new(locale: "es")

    assert_equal "es", spanish.locale

    I18n.with_locale "es" do
      danish = ActionText::RichText.new(locale: "dk")

      assert_equal "dk", danish.locale
    end
  end

  test "#body= sets the locale for a String value" do
    model = ActionText::RichText.new locale: "es"

    model.body = "<h1>Hola mundo</h1>"

    assert_equal "es", model.body.locale
  end

  test "#body= sets the locale for an ActionText::Content value" do
    model = ActionText::RichText.new locale: "es"
    content = ActionText::Content.new("<h1>Hola mundo</h1>")

    model.body = content

    assert_equal "es", model.body.locale
    assert_equal I18n.locale, content.locale, "does not write to the instance"
  end

  test "#body= ignores the locale for a nil value" do
    model = ActionText::RichText.new locale: "es"

    model.body = nil

    assert_nil model.body&.locale
  end
end
