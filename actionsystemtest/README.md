# Action System Test

Action System Test adds Capybara integration to your Rails application and makes
it possible to test your application and it's JavaScript interactions.

This allows you to test the entire user experience of your application rather
than your controllers, models, and views separately.

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

  test "creating a new user" do
    click_on "New User"

    fill_in "Name", with: "Arya"

    click_on "Create User"

    assert_text "Arya"
  end
end
```

First we visit the +users_path+. From there we are going to use Action System
Test to create a new user. The test will click on the "New User" button. Then
it will fill in the "Name" field with "Arya" and click on the "Create User"
button. Lastly, we assert that the text on the Users show page is what we
expected, which in this case is "Arya".

### Configuration

When generating a new application Rails will include the Capybara gem, the
Selenium gem, and a <tt>system_test_helper.rb</tt> file. The
<tt>system_test_helper.rb</tt> file is where you can change the desired
configuration if Rails doesn't work out of the box for you.

The <tt>system_test_helper.rb</tt> file provides a home for all of your Capybara
and Action System Test configuration.

The default configuration uses the Selenium driver, with the Chrome browser,
and a screen size of 1400x1400.

Changing the configuration is as simple as changing the driver in your
<tt>system_test_helper.rb</tt>

If you want to change the default settings of the Rails provided Selenium
you can change `driven_by` in the helper file.

The driver name is a required argument for `driven_by`. The optional arguments
that can be passed to `driven_by` are `:using` for the browser (this will only
be used for non-headless drivers like Selenium), and `:screen_size` to change
the size of the screen for screenshots.

Below are some examples for changing the default configuration settings for
system tests:

Changing the browser and screen size:

```ruby
class ActionSystemTestCase < ActionSystemTest::Base
  driven_by :selenium, using: :firefox, screen_size: [ 800, 800 ]
end
```

The browser setting is not used by headless drivers like Poltergeist. When
using a headless driver simply leave out the `:using` argument.

```ruby
class ActionSystemTestCase < ActionSystemTest::Base
  driven_by :poltergeist
end
```

### Running the tests

Because system tests are time consuming and can use a lot of resources
they are not automatically run with `rails test`.

To run all the tests in the system suite run the system test command:

```
$ rails test:system
```
