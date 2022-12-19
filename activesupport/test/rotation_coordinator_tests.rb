# frozen_string_literal: true

module RotationCoordinatorTests
  extend ActiveSupport::Concern

  included do
    setup do
      @coordinator = make_coordinator.rotate_defaults
    end

    test "builds working codecs" do
      codec = @coordinator["salt"]
      other_codec = @coordinator["other salt"]

      assert_equal "message", roundtrip("message", codec)
      assert_nil roundtrip("message", codec, other_codec)
    end

    test "memoizes codecs" do
      assert_same @coordinator["salt"], @coordinator["salt"]
    end

    test "can override codecs" do
      @coordinator["other salt"] = @coordinator["salt"]
      assert_same @coordinator["salt"], @coordinator["other salt"]
    end

    test "configures codecs with rotations" do
      @coordinator.rotate(digest: "MD5")
      codec = @coordinator["salt"]
      obsolete_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]

      assert_equal "message", roundtrip("message", obsolete_codec, codec)
      assert_nil roundtrip("message", codec, obsolete_codec)
    end

    test "#transitional swaps the first two rotations when enabled" do
      coordinator = make_coordinator.rotate(digest: "SHA1")
      coordinator.rotate(digest: "MD5")
      coordinator.rotate(digest: "MD4")
      coordinator.transitional = true

      codec = coordinator["salt"]
      sha1_codec = (make_coordinator.rotate(digest: "SHA1"))["salt"]
      md5_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]
      md4_codec = (make_coordinator.rotate(digest: "MD4"))["salt"]

      assert_equal "message", roundtrip("message", codec, md5_codec)
      assert_nil roundtrip("message", codec, sha1_codec)

      assert_equal "message", roundtrip("message", sha1_codec, codec)
      assert_equal "message", roundtrip("message", md5_codec, codec)
      assert_equal "message", roundtrip("message", md4_codec, codec)
    end

    test "#transitional works with a single rotation" do
      @coordinator.transitional = true

      assert_nothing_raised do
        codec = @coordinator["salt"]
        assert_equal "message", roundtrip("message", codec)

        different_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]
        assert_nil roundtrip("message", different_codec, codec)
      end
    end

    test "can clear rotations" do
      @coordinator.clear_rotations.rotate(digest: "MD5")
      codec = @coordinator["salt"]
      similar_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]

      assert_equal "message", roundtrip("message", codec, similar_codec)
    end

    test "configures codecs with on_rotation" do
      rotated = 0
      @coordinator.on_rotation { rotated += 1 }
      @coordinator.rotate(digest: "MD5")
      codec = @coordinator["salt"]
      obsolete_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]

      assert_equal "message", roundtrip("message", obsolete_codec, codec)
      assert_equal 1, rotated
    end

    test "prevents adding a rotation after rotations have been applied" do
      @coordinator["salt"]
      assert_raises { @coordinator.rotate(digest: "MD5") }
    end

    test "prevents clearing rotations after rotations have been applied" do
      @coordinator["salt"]
      assert_raises { @coordinator.clear_rotations }
    end

    test "prevents changing on_rotation after on_rotation has been applied" do
      @coordinator["salt"]
      assert_raises { @coordinator.on_rotation { "this block will not be evaluated" } }
    end

    test "raises when building an codec and no rotations are configured" do
      @coordinator.clear_rotations
      assert_raises { @coordinator["salt"] }
    end
  end
end
