# encoding: utf-8

require 'abstract_unit'

class FlashHelperTest < ActionView::TestCase
  tests ActionView::Helpers::FlashHelper

  def test_flash_messages_without_messages
    assert flash_messages.blank?
  end         

  def test_flash_messages_is_html_safe
    flash[:notice] = "Some random resource was succesfuly saved."

    assert flash_messages.html_safe?
  end                  

  def test_flash_messages_with_notice_message
    flash[:notice] = "Everything is ok."

    assert_equal %Q(<p class="flash flash_notice">Everything is ok.</p>\n), flash_messages    
  end

  def test_flash_messages_with_alert_message
    flash[:alert] = "10 minutes to world explosion."

    assert_equal %Q(<p class="flash flash_alert">10 minutes to world explosion.</p>\n), flash_messages    
  end                               

  def test_flash_messages_with_notice_and_alert_messages
    flash[:notice] = "This application is just fine."
    flash[:alert] = "The previous message is wrong!"

    messages = flash_messages

    assert messages.include?(%Q(<p class="flash flash_notice">This application is just fine.</p>\n))
    messages.gsub!(%Q(<p class="flash flash_notice">This application is just fine.</p>\n), "")

    assert messages.include?(%Q(<p class="flash flash_alert">The previous message is wrong!</p>\n))
    messages.gsub!(%Q(<p class="flash flash_alert">The previous message is wrong!</p>\n), "")    

    assert messages.blank?
  end                     

  def test_flash_messages_with_custom_parent_element
    flash[:notice] = "Look at me mom, I'm on a flash message!"

    assert_equal %Q(<div class="flash flash_notice">Look at me mom, I'm on a flash message!</div>\n), flash_messages(:with_parent_element => :div)
  end

  def test_flash_messages_with_custom_class_for_parent_element
    flash[:alert] = "Houston, we have a problem."  

    assert_equal %Q(<p class="message message_alert">Houston, we have a problem.</p>\n), flash_messages(:using_class => :message)    
  end

  def test_flash_messages_without_class_on_parent_element
    flash[:notice] = "Up and running!"

    assert_equal %Q(<p>Up and running!</p>\n), flash_messages(:using_class => nil)    
  end
end