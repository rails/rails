# Action System Test

Action System Test adds Capybara integration to your Rails application for
acceptance testing. This allows you to test the entire user experience
of your application rather than just your controllers, or just your models.

Action System Test provides all of the setup out of the box for you to use
Capybara with the Selenium Driver in your Rails application. Changing the
default configuration is simple, yet flexible.

## Examples

### Usage

By default Rails provides applications with system testing through Capybara
and defaults to using the Selenium driver. The configuration set by Rails
means that when you generate an application system tests will work out of
the box, without you having to change any of the configuration requirements.

Action System Test uses all the helpers from Capybara, but abstracts away the
setup required to get running. Below is an example Action System Test.

```ruby
class UsersTest < ActionSystemTestCase
  setup do
    visit users_path
  end

  test 'creating a new user' do
    click_on 'New User'

    fill_in 'Name', with: 'Arya'

    click_on 'Create User'

    assert_text 'Arya'
  end
end
```

First we visit the +users_path+. From there we are going to use Action System
Test to create a new user. The test will click on the "New User" button. Then
it will fill in the "Name" field with "Arya" and click on the "Create User"
button. Lastly, we assert that the text on the Users show page is what we
expected, which in this case is "Arya".

For more helpers and how to write Capybara tests visit Capybara's README.

### Configuration

When generating a new application Rails will include the Capybara gem, the
Selenium gem, and a <tt>system_test_helper.rb</tt> file. The
<tt>system_test_helper.rb</tt> file is where you can change the desired
configuration if Rails doesn't work out of the box for you.

The <tt>system_test_helper.rb</tt> file provides a home for all of your Capybara
and Action System Test configuration.

Rails preset configuration for Capybara with Selenium defaults to Puma for
the web server on port 28100, Chrome for the browser, and a screen size of
1400 x 1400.

Changing the configuration is as simple as changing the driver in your
<tt>system_test_helper.rb</tt>

If you want to change the default settings of the Rails provided Selenium
configuration options you can initialize a new <tt>RailsSeleniumDriver</tt>
object.

```ruby
class ActionSystemTestCase < ActionSystemTest::Base
  ActionSystemTest.driver = RailsSeleniumDriver.new(
    browser: :firefox,
    server: :webrick
  )
end
```

Capybara itself provides 4 drivers: RackTest, Selenium, Webkit, and Poltergeist.
Action System Test provides a shim between Rails and Capybara for these 4 drivers.
Please note, that Rails is set up to use the Puma server by default for these
4 drivers. Puma is the default in Rails and therefore is set as the default in
the Rails Capybara integration.

To set your application tests to use any of Capybara's defaults with no configuration,
set the following in your <tt>system_test_helper.rb</tt> file and follow setup instructions
for environment requirements of these drivers.

The possible settings are +:rack_test+, +:selenium+, +:webkit+, or +:poltergeist+.

```ruby
class ActionSystemTestCase < ActionSystemTest::Base
  ActionSystemTest.driver = :poltergeist
end
```

If you want to change the default server (puma) or port (28100) for Capbyara drivers
you can initialize a new object.

```ruby
class ActionSystemTestCase < ActionSystemTest::Base
  ActionSystemTest.driver = ActionSystemTest::DriverAdapters::CapybaraDriver.new(
    name: :poltergeist,
    server: :webkit,
    port: 3000
  )
end
```
