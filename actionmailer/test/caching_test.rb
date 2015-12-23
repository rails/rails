
require 'abstract_unit'
require 'set'

require 'action_dispatch'
require 'active_support/time'

require 'mailers/base_mailer'
require 'mailers/proc_mailer'
require 'mailers/asset_mailer'
require "byebug"

class CachingTest < ActiveSupport::TestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  def random_name
    (0...8).map { (65 + rand(26)).chr }.join
  end

  test "mail template cache nothing by default" do
    email1 = BaseMailer.welcome_with_random_string("uncached")
    email2 = BaseMailer.welcome_with_random_string("uncached")

    assert_not_equal(email1.body.encoded.strip, email2.body.encoded.strip)
  end

  test "mail template caches value just like normal view" do
    email1 = BaseMailer.welcome_with_random_string("cached")
    email2 = BaseMailer.welcome_with_random_string("cached")

    assert_equal(email1.body.encoded.strip, email2.body.encoded.strip)
  end
end
