require 'abstract_unit'

class FormOptionsHelperI18nTests < ActionView::TestCase
  tests ActionView::Helpers::FormOptionsHelper

  def setup
    @prompt_message = 'Select!'
    I18n.backend.send(:init_translations)
    I18n.backend.store_translations :en, :support => { :select => { :prompt => @prompt_message } }
  end

  def teardown
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_select_with_prompt_true_translates_prompt_message
    I18n.expects(:translate).with('support.select.prompt', { :default => 'Please select' })
    select('post', 'category', [], :prompt => true)
  end

  def test_select_with_translated_prompt
    assert_dom_equal(
      %Q(<select id="post_category" name="post[category]"><option value="">#{@prompt_message}</option>\n</select>),
      select('post', 'category', [], :prompt => true)
    )
  end
end