# frozen_string_literal: true

require "rail_inspector/changelog"
require "test/test_helpers/changelog_fixtures"

class TestChangelog < Minitest::Test
  include ChangelogFixtures

  def test_parses_changelog_file
    @changelog = changelog_fixture("railties_06e9fbd.md")

    assert_equal 21, entries.length
  end

  def test_entries_without_author_are_invalid
    @changelog = changelog_fixture("active_support_9f0b8eb.md")

    assert_equal 2, offenses.length
  end

  def test_valid_username_is_valid_author
    assert_valid_entry <<~CHANGELOG
      *   Cool change.

          *1337-rails-c0d3r*
    CHANGELOG
  end

  def test_parses_with_extra_newlines
    @changelog = changelog_fixture("action_mailbox_83d85b2.md")

    assert_equal 0, entries.length
  end

  def test_entries_with_trailing_whitespace_are_invalid
    @changelog = changelog_fixture("active_record_936a862.md")

    assert_equal 16, offenses.length
  end

  def test_entries_without_four_leading_spaces
    @changelog = changelog_fixture("active_record_238432d.md")

    assert_equal 5, offenses.length
  end

  def test_entries_with_incorrectly_indented_header
    @changelog = changelog_fixture("active_record_51852d2.md")

    assert_equal 1, offenses.length
  end

  def test_header_ending_with_star_not_treated_as_author
    @changelog = changelog_fixture("action_pack_69d504.md")

    assert_equal 0, offenses.length
  end

  def test_release_header_is_not_treated_as_offense
    @changelog = changelog_fixture("action_view.md")

    assert_equal 0, offenses.length
  end

  def test_no_changes_not_treated_as_offense
    @changelog = changelog_fixture("action_mailbox.md")

    assert_equal 0, offenses.length
  end

  def test_invalid_header_does_not_cause_infinite_loop
    Timeout.timeout(1) do
      @changelog = changelog_fixture("action_mailbox_invalid.md")
      assert_equal 2, offenses.length
    end
  rescue Timeout::Error
    flunk "Parsing action_mailbox_invalid.md took too long"
  end

  def test_validate_authors
    assert_offense(<<~CHANGELOG)
      *   Fix issue in CHANGELOG linting
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ CHANGELOG entry is missing authors.
    CHANGELOG
  end

  def test_validate_leading_whitespace_for_header
    assert_offense(<<~CHANGELOG)
      * Fix leading whitespace in CHANGELOG
      ^^^^ CHANGELOG header must start with '*' and 3 spaces

          *Hartley McGuire*
    CHANGELOG

    assert_offense(<<~CHANGELOG)
      *    Fix leading whitespace in CHANGELOG
      ^^^^ CHANGELOG header must start with '*' and 3 spaces

          *Hartley McGuire*
    CHANGELOG
  end

  def test_validate_leading_whitespace_for_body
    assert_offense(<<~CHANGELOG)
      *   Fix leading whitespace in CHANGELOG

        *Hartley McGuire*
      ^^^^ CHANGELOG line must be indented 4 spaces
    CHANGELOG
  end

  def test_validate_trailing_whitespace
    assert_offense(<<~CHANGELOG)
      *   Fix trailing whitespace in CHANGELOG#{' '}
                                              ^ Trailing whitespace detected.

          *Hartley McGuire*
    CHANGELOG

    assert_offense(<<~CHANGELOG)
      *   Fix trailing whitespace in CHANGELOG
      #{' '}
      ^ Trailing whitespace detected.
          *Hartley McGuire*
    CHANGELOG
  end

  private
    def entries
      @changelog.entries
    end

    def offenses
      entries.flat_map(&:offenses)
    end

    def assert_valid_entry(source)
      entry = RailInspector::Changelog::Entry.new(source.lines(chomp: true), 1)
      assert_empty entry.offenses, "Entry has offenses"
    end

    ANNOTATION_PATTERN = /\s*\^+ /

    def assert_offense(source)
      lines = []
      annotation = nil

      source.each_line(chomp: true) do |line|
        if ANNOTATION_PATTERN.match?(line)
          annotation = [lines.length, line]
        else
          lines << line
        end
      end

      entry = RailInspector::Changelog::Entry.new(lines, 1)

      assert_equal 1,
                   entry.offenses.length,
                   "Entry has the wrong number of offenses"
      offense = entry.offenses.first

      assert_equal annotation[0],
                   offense.line_number,
                   "Offense has incorrect line number"
      assert_equal lines[annotation[0] - 1],
                   offense.line,
                   "Offense has incorrect line"

      annotation_message = annotation[1].gsub(ANNOTATION_PATTERN, "")
      assert_equal annotation_message,
                   offense.message,
                   "Offense has incorrect message"

      annotation_start = annotation[1].index("^") + 1
      annotation_end = annotation[1].rindex("^") + 1
      assert_equal annotation_start..annotation_end,
                   offense.range,
                   "Offense has incorrect range"
    end
end
