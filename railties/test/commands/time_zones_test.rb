# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::TimeZonesTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "`rails time:zones` shows all time zones" do
    result = run_time_zones_command
    ActiveSupport::TimeZone.all.each do |zone|
      assert_time_zone(zone, result)
    end
  end

  test "`rails time:zones -OFFSET` shows time zone for UTC offset" do
    result = run_time_zones_command("-8")
    assert_time_zone(ActiveSupport::TimeZone["Tijuana"], result)
    assert_no_time_zone(ActiveSupport::TimeZone["Alaska"], result)
    assert_no_time_zone(ActiveSupport::TimeZone["Hawaii"], result)
  end

  test "`rails time:zones -OFFSET` works with HH:MM format" do
    result = run_time_zones_command("6:30")
    assert_time_zone(ActiveSupport::TimeZone["Rangoon"], result)
  end

  test "`rails time:zones:us` shows us time zones" do
    result = rails "time:zones:us"
    assert_time_zone(ActiveSupport::TimeZone["Alaska"], result)
    assert_time_zone(ActiveSupport::TimeZone["Hawaii"], result)
    assert_no_time_zone(ActiveSupport::TimeZone["Paris"], result)
  end

  test "`OFFSET=6 rails time:zones:all CN` filters on offset and country code" do
    ENV["OFFSET"] = "6"
    result = rails "time:zones:all", "CN"
    assert_time_zone(ActiveSupport::TimeZone["Urumqi"], result)
    assert_no_time_zone(ActiveSupport::TimeZone["Beijing"], result)
  end

  test "`rails time:help` shows USAGE" do
    stdout = capture(:stdout) do
      Rails::Command.invoke("time:help")
    end
    assert_match %r"bin/rails time:zones:all", stdout
    assert_match %r"bin/rails time:zones:us", stdout
    assert_match %r"bin/rails time:zones:local", stdout
    assert_match %r"Examples", stdout
  end

  test "`rails time:zones:help` subcommands" do
    stdout = capture(:stdout) do
      Rails::Command.invoke("time:zones:help")
    end
    assert_match %r"bin/rails time:zones:all", stdout
    assert_match %r"bin/rails time:zones:us", stdout
    assert_match %r"bin/rails time:zones:local", stdout
    assert_no_match %r"Examples", stdout
  end

  private
    def assert_time_zone(zone, output)
      group = "* UTC #{zone.formatted_offset} *"
      assert_match %r/#{Regexp.escape group}\n(?:.+\n)*#{Regexp.escape zone.name}/, output
    end

    def assert_no_time_zone(zone, output)
      assert_no_match zone.name, output
    end

    def run_time_zones_command(args = [])
      rails "time:zones", args
    end
end
