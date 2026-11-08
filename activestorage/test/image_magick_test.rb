# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_storage/image_magick"
require "active_storage/analyzer/image_analyzer/image_magick"
require "active_storage/transformers/image_magick"

class ActiveStorage::ImageMagickTest < ActiveSupport::TestCase
  SHIPPED_POLICY = File.read(File.join(ActiveStorage::ImageMagick::POLICY_DIRECTORY, "policy.xml"))
  SHIPPED_RULES = SHIPPED_POLICY.scan(/<policy domain="(\w+)"[^>]*pattern="([^"]+)"/)
  DENIED_CODERS = %w[ MSL EPHEMERAL TEXT MPC SHOW WIN PLT URL HTTP HTTPS FTP FILE PS PS2 PS3 EPS EPS2 EPS3 EPI EPSF EPSI EPT EPT2 EPT3 PDF AI EPDF PDFA POCKETMOD XPS PCL ].freeze
  GHOSTSCRIPT_MODULES = %w[ PS PS2 PS3 EPT PDF ].freeze

  VARIABLE_FIXTURES = {
    "image/png" => "racecar.png",
    "image/gif" => "image.gif",
    "image/jpeg" => "racecar.jpg",
    "image/tiff" => "racecar.tif",
    "image/bmp" => "colors.bmp",
    "image/vnd.adobe.photoshop" => "icon.psd",
    "image/vnd.microsoft.icon" => "favicon.ico",
    "image/webp" => "valley.webp",
    "image/avif" => "racecar.avif",
    "image/heic" => "racecar.heic",
    "image/heif" => "racecar.heif",
  }.freeze

  test "every rule in the shipped policy is loaded" do
    loaded = policy_listing.split(/^Path: /).find { |section| section.start_with?(ActiveStorage::ImageMagick::POLICY_DIRECTORY) }

    assert_not_nil loaded
    assert_equal SHIPPED_RULES.size, loaded.scan(/^  Policy: /).size
  end

  test "the shipped policy denies exactly the expected coders, the Ghostscript delegate, and @filename indirection" do
    assert_equal DENIED_CODERS, SHIPPED_RULES.filter_map { |domain, pattern| pattern if domain == "coder" }
    assert_equal [ [ "delegate", "gs" ], [ "path", "@*" ] ], SHIPPED_RULES.reject { |domain, _| domain == "coder" }
  end

  test "every Ghostscript-backed coder is denied by coder" do
    assert_empty gs_backed_coders - DENIED_CODERS
  end

  DENIED_CODERS.each do |coder|
    test "the shipped policy denies the #{coder} coder" do
      if coder_registered?(coder)
        error = assert_raises(MiniMagick::Error) { invoke_coder(coder) }
        assert_match(/security policy/, error.message)
      else
        force_skip "this ImageMagick has no #{coder} coder"
      end
    end
  end

  test "the shipped policy refuses @filename indirection" do
    error = assert_raises(MiniMagick::Error) do
      MiniMagick.identify { |identify| identify << "@#{file_fixture("racecar.jpg")}" }
    end
    assert_match(/security policy .@/, error.message)
  end

  test "the variable content types are all covered by a fixture" do
    assert_equal ActiveStorage.variable_content_types.sort, VARIABLE_FIXTURES.keys.sort
  end

  VARIABLE_FIXTURES.each do |content_type, fixture|
    test "#{content_type} still analyzes and transforms under the shipped policy" do
      coder = coder_for(fixture)
      skip "#{content_type}: this ImageMagick has no #{coder} coder" unless coder_registered?(coder)

      blob = create_file_blob(filename: fixture, content_type: content_type)
      metadata = ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(blob).metadata
      assert_operator metadata[:width], :>, 0
      assert_operator metadata[:height], :>, 0

      transformer = ActiveStorage::Transformers::ImageMagick.new(resize_to_limit: [ 8, 8 ])
      transformer.transform(file_fixture(fixture).open, format: "png") do |output|
        assert_operator output.size, :>, 0
      end
    end
  end

  test "image/svg+xml still analyzes under the shipped policy" do
    skip "this ImageMagick has no SVG coder" unless coder_registered?("SVG")

    blob = create_file_blob(filename: "icon.svg", content_type: "image/svg+xml")
    metadata = ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(blob).metadata

    assert_equal 792, metadata[:width]
    assert_equal 584, metadata[:height]
  end

  test "the shipped policy directory is added to the search path, not substituted for it" do
    paths = policy_listing.scan(/^Path: (.+)$/).flatten

    assert_includes paths, "#{ActiveStorage::ImageMagick::POLICY_DIRECTORY}#{File::SEPARATOR}policy.xml"
    assert_includes paths, "[built-in]"
  end

  test "the shipped policy directory comes before an operator's own" do
    assert_equal ActiveStorage::ImageMagick::POLICY_DIRECTORY, ActiveStorage::ImageMagick.configure_path(nil)
    assert_equal ActiveStorage::ImageMagick::POLICY_DIRECTORY, ActiveStorage::ImageMagick.configure_path("")
    assert_equal "#{ActiveStorage::ImageMagick::POLICY_DIRECTORY}#{File::PATH_SEPARATOR}/etc/magick",
      ActiveStorage::ImageMagick.configure_path("/etc/magick")
  end

  test "applying the policy again keeps the shipped directory first, once" do
    with_cli_env("MAGICK_CONFIGURE_PATH" => ActiveStorage::ImageMagick.configure_path("/etc/magick")) do
      ActiveStorage::ImageMagick.apply_policy

      assert_equal ActiveStorage::ImageMagick.configure_path("/etc/magick"), MiniMagick.cli_env["MAGICK_CONFIGURE_PATH"]
    end
  end

  test "applying the policy after initialization picks up a MAGICK_CONFIGURE_PATH set after Active Storage loaded" do
    with_cli_env("MAGICK_CONFIGURE_PATH" => ActiveStorage::ImageMagick::POLICY_DIRECTORY) do
      with_env("MAGICK_CONFIGURE_PATH" => "/etc/magick") do
        ActiveStorage::ImageMagick.apply_policy

        assert_equal ActiveStorage::ImageMagick.configure_path("/etc/magick"), MiniMagick.cli_env["MAGICK_CONFIGURE_PATH"]
      end
    end
  end

  test "applying the policy after initialization restores it to a MiniMagick.cli_env an initializer replaced" do
    previous, MiniMagick.cli_env = MiniMagick.cli_env, { "OMP_NUM_THREADS" => "1" }

    ActiveStorage::ImageMagick.apply_policy

    assert_equal({ "OMP_NUM_THREADS" => "1", "MAGICK_CONFIGURE_PATH" => ActiveStorage::ImageMagick::POLICY_DIRECTORY }, MiniMagick.cli_env)
  ensure
    MiniMagick.cli_env = previous
  end

  test "an operator's policy after the shipped one can allow a coder we deny" do
    with_operator_policy %(<policy domain="coder" rights="read|write" pattern="TEXT"/>) do
      assert_no_match(/security policy/, coder_error_message("TEXT"))
    end
  end

  test "the shipped policy allows label: text rendering" do
    skip "this ImageMagick has no LABEL coder" unless coder_registered?("LABEL")

    assert_no_match(/security policy/, coder_error_message("LABEL"))
  end

  test "an operator's policy after the shipped one can deny a coder we allow" do
    with_operator_policy %(<policy domain="coder" rights="none" pattern="JPEG"/>) do
      error = assert_raises(MiniMagick::Error) do
        MiniMagick.identify { |identify| identify << file_fixture("racecar.jpg").to_s }
      end
      assert_match(/security policy/, error.message)
    end
  end

  private
    def policy_listing
      MiniMagick.identify { |identify| identify.list "policy" }
    end

    def registered_formats
      @registered_formats ||= MiniMagick.identify { |identify| identify.list "format" }
        .scan(/^\s*(\w+)\*?\s+(\w+)\s+([rw+-]{3})/)
        .select { |_token, _module, rights| rights.match?(/[rw]/) }
    end

    def registered_coders
      registered_formats.map { |token, _module, _rights| token }
    end

    def gs_backed_coders
      registered_formats.filter_map { |token, mod, _rights| token if GHOSTSCRIPT_MODULES.include?(mod) }
    end

    def coder_registered?(coder)
      registered_coders.include?(coder)
    end

    def coder_for(fixture)
      { "jpg" => "JPEG", "tif" => "TIFF", "ico" => "ICO" }.fetch(File.extname(fixture).delete("."), File.extname(fixture).delete(".").upcase)
    end

    def invoke_coder(coder)
      case coder
      when "MSL"
        with_tempfile("script.msl", %(<image><read filename="#{file_fixture("racecar.jpg")}"/></image>)) do |path|
          MiniMagick.identify { |identify| identify << "msl:#{path}" }
        end
      when "PS", "EPS", "EPI", "EPSF", "EPSI", "EPT", "EPT2", "EPT3"
        with_tempfile("page.ps", "%!PS\nshowpage\n") do |path|
          MiniMagick.identify { |identify| identify << "#{coder.downcase}:#{path}" }
        end
      when "PDF", "AI", "EPDF", "PDFA", "POCKETMOD"
        MiniMagick.identify { |identify| identify << "#{coder.downcase}:#{file_fixture("cropped.pdf")}" }
      when "XPS", "PCL"
        with_tempfile("page.ps", "%!PS\nshowpage\n") do |path|
          MiniMagick.identify { |identify| identify << "#{coder.downcase}:#{path}" }
        end
      when "MPC"
        MiniMagick.identify { |identify| identify << "mpc:#{file_fixture("racecar.jpg")}" }
      when "FILE"
        MiniMagick.identify { |identify| identify << "file://#{file_fixture("racecar.jpg")}" }
      when "TEXT", "EPHEMERAL"
        MiniMagick.identify { |identify| identify << "#{coder.downcase}:#{file_fixture("racecar.jpg")}" }
      when "LABEL"
        MiniMagick.identify { |identify| identify << "label:hello" }
      when "PS2", "PS3", "EPS2", "EPS3"
        Tempfile.create([ "page", ".#{coder.downcase}" ]) do |file|
          MiniMagick.convert { |convert| convert << file_fixture("racecar.jpg").to_s << "#{coder.downcase}:#{file.path}" }
        end
      when "URL", "HTTP", "HTTPS", "FTP"
        MiniMagick.identify { |identify| identify << "#{coder.downcase}://127.0.0.1:1/racecar.jpg" }
      when "SHOW", "WIN", "PLT"
        with_display_disabled do
          MiniMagick.convert { |convert| convert << file_fixture("racecar.jpg").to_s << "#{coder.downcase}:" }
        end
      else
        flunk "no invocation defined for the #{coder} coder; add one to invoke_coder"
      end
    end

    def coder_error_message(coder)
      invoke_coder(coder)
      ""
    rescue MiniMagick::Error => error
      error.message
    end

    def with_tempfile(name, contents)
      Tempfile.create(name.split(".").then { |base, ext| [ base, ".#{ext}" ] }) do |file|
        file.write contents
        file.flush
        yield file.path
      end
    end

    def with_display_disabled(&block)
      with_cli_env("DISPLAY" => "", "WAYLAND_DISPLAY" => "", &block)
    end

    def with_operator_policy(rules, &block)
      Dir.mktmpdir do |directory|
        File.write File.join(directory, "policy.xml"), "<policymap>#{rules}</policymap>"
        with_cli_env("MAGICK_CONFIGURE_PATH" => ActiveStorage::ImageMagick.configure_path(directory), &block)
      end
    end

    def with_env(overrides)
      previous = ENV.to_h.slice(*overrides.keys)
      ENV.update(overrides)
      yield
    ensure
      overrides.each_key { |key| ENV[key] = previous[key] }
    end

    def with_cli_env(overrides)
      previous, MiniMagick.cli_env = MiniMagick.cli_env, MiniMagick.cli_env.merge(overrides)
      yield
    ensure
      MiniMagick.cli_env = previous
    end
end
