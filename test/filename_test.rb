require "test_helper"

class ActiveVault::FilenameTest < ActiveSupport::TestCase
  test "sanitize" do
    "%$|:;/\t\r\n\\".each_char do |character|
      filename = ActiveVault::Filename.new("foo#{character}bar.pdf")
      assert_equal 'foo-bar.pdf', filename.sanitized
      assert_equal 'foo-bar.pdf', filename.to_s
    end
  end

  test "sanitize transcodes to valid UTF-8" do
    { "\xF6".force_encoding(Encoding::ISO8859_1) => "ö",
      "\xC3".force_encoding(Encoding::ISO8859_1) => "Ã",
      "\xAD" => "�",
      "\xCF" => "�",
      "\x00" => "",
    }.each do |actual, expected|
      assert_equal expected, ActiveVault::Filename.new(actual).sanitized
    end
  end

  test "strips RTL override chars used to spoof unsafe executables as docs" do
    # Would be displayed in Windows as "evilexe.pdf" due to the right-to-left
    # (RTL) override char!
    assert_equal 'evil-fdp.exe', ActiveVault::Filename.new("evil\u{202E}fdp.exe").sanitized
  end

  test "compare case-insensitively" do
    assert_operator ActiveVault::Filename.new('foobar.pdf'), :==, ActiveVault::Filename.new('FooBar.PDF')
  end

  test "compare sanitized" do
    assert_operator ActiveVault::Filename.new('foo-bar.pdf'), :==, ActiveVault::Filename.new("foo\tbar.pdf")
  end
end
