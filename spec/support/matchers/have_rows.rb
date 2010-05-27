module Matchers
  def have_rows(expected)
    simple_matcher "have rows" do |given, matcher|
      found, got, expected = [], [], expected.map { |r| r.tuple }
      given.each do |row|
        got << row.tuple
        found << expected.find { |r| row.tuple == r }
      end

      matcher.failure_message = "Expected to get:\n" \
        "#{expected.map {|r| "  #{r.inspect}" }.join("\n")}\n" \
        "instead, got:\n" \
        "#{got.map {|r| "  #{r.inspect}" }.join("\n")}"

      found.compact.length == expected.length && got.compact.length == expected.length
    end
  end
end
