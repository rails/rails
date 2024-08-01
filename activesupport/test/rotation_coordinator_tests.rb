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

    test "raises when building a codec and no rotations are configured" do
      assert_raises { make_coordinator["salt"] }
    end

    test "#rotate supports a block" do
      coordinator = make_coordinator.rotate do |salt|
        { digest: salt == "salt" ? "SHA1" : "MD5" }
      end

      sha1_coordinator = make_coordinator.rotate(digest: "SHA1")
      md5_coordinator = make_coordinator.rotate(digest: "MD5")

      assert_equal "message", roundtrip("message", coordinator["salt"], sha1_coordinator["salt"])
      assert_nil roundtrip("message", coordinator["salt"], md5_coordinator["salt"])

      assert_equal "message", roundtrip("message", coordinator["other salt"], md5_coordinator["other salt"])
      assert_nil roundtrip("message", coordinator["other salt"], sha1_coordinator["other salt"])
    end

    test "#rotate block receives salt in its original form" do
      coordinator = make_coordinator.rotate do |salt|
        assert_equal :salt, salt
        {}
      end

      coordinator[:salt]
    end

    test "#rotate raises when both a block and options are provided" do
      assert_raises ArgumentError do
        make_coordinator.rotate(digest: "MD5") { {} }
      end
    end

    test "#rotate block can return nil to skip a rotation for specific salts" do
      coordinator = make_coordinator.rotate(digest: "SHA1")
      coordinator.rotate do |salt|
        { digest: "MD5" } if salt == "salt"
      end

      sha1_coordinator = make_coordinator.rotate(digest: "SHA1")
      md5_coordinator = make_coordinator.rotate(digest: "MD5")

      assert_equal "message", roundtrip("message", sha1_coordinator["salt"], coordinator["salt"])
      assert_equal "message", roundtrip("message", md5_coordinator["salt"], coordinator["salt"])

      assert_equal "message", roundtrip("message", sha1_coordinator["other salt"], coordinator["other salt"])
      assert_nil roundtrip("message", md5_coordinator["other salt"], coordinator["other salt"])
    end

    test "raises when building a codec and no rotations are configured for a specific salt" do
      coordinator = make_coordinator.rotate do |salt|
        { digest: "MD5" } if salt == "salt"
      end

      assert_nothing_raised { coordinator["salt"] }
      error = assert_raises { coordinator["other salt"] }
      assert_match "other salt", error.message
    end

    test "#transitional swaps the first two rotations when enabled" do
      coordinator = make_coordinator.rotate(digest: "SHA1")
      coordinator.rotate(digest: "MD5")
      coordinator.rotate(digest: "SHA256")
      coordinator.transitional = true

      codec = coordinator["salt"]
      sha1_codec = (make_coordinator.rotate(digest: "SHA1"))["salt"]
      md5_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]
      sha256_codec = (make_coordinator.rotate(digest: "SHA256"))["salt"]

      assert_equal "message", roundtrip("message", codec, md5_codec)
      assert_nil roundtrip("message", codec, sha1_codec)

      assert_equal "message", roundtrip("message", sha1_codec, codec)
      assert_equal "message", roundtrip("message", md5_codec, codec)
      assert_equal "message", roundtrip("message", sha256_codec, codec)
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

    test "#transitional treats a nil first rotation as a new rotation" do
      coordinator = make_coordinator
      coordinator.rotate do |salt|       # (3) Finally, one salt upgraded to SHA1
        { digest: "SHA1" } if salt == "salt"
      end
      coordinator.rotate(digest: "MD5")  # (2) Then, everything upgraded to MD5
      coordinator.rotate(digest: "SHA256")  # (1) Originally, everything used SHA256
      coordinator.transitional = true

      sha1_coordinator = make_coordinator.rotate(digest: "SHA1")
      md5_coordinator = make_coordinator.rotate(digest: "MD5")

      # "salt" encodes with MD5 and can decode SHA1 (i.e. [SHA1, MD5, SHA256] => [MD5, SHA1, SHA256])
      assert_equal "message", roundtrip("message", coordinator["salt"], md5_coordinator["salt"])
      assert_equal "message", roundtrip("message", sha1_coordinator["salt"], coordinator["salt"])

      # "other salt" encodes with MD5 and cannot decode SHA1 (i.e. [nil, MD5, SHA256] => [MD5, SHA256])
      assert_equal "message", roundtrip("message", coordinator["other salt"], md5_coordinator["other salt"])
      assert_nil roundtrip("message", sha1_coordinator["other salt"], coordinator["other salt"])
    end

    test "#transitional swaps the first rotation with the next non-nil rotation" do
      coordinator = make_coordinator
      coordinator.rotate(digest: "SHA1") # (3) Finally, everything upgraded to SHA1
      coordinator.rotate do |salt|       # (2) Then, one salt upgraded to SHA1
        { digest: "SHA1" } if salt == "salt"
      end
      coordinator.rotate(digest: "MD5")  # (1) Originally, everything used MD5
      coordinator.transitional = true

      sha1_coordinator = make_coordinator.rotate(digest: "SHA1")
      md5_coordinator = make_coordinator.rotate(digest: "MD5")

      # "salt" encodes with SHA1 and can decode SHA1 (i.e. [SHA1, SHA1, MD5] => [SHA1, MD5])
      assert_equal "message", roundtrip("message", coordinator["salt"], sha1_coordinator["salt"])
      assert_equal "message", roundtrip("message", sha1_coordinator["salt"], coordinator["salt"])

      # "other salt" encodes with MD5 and can decode SHA1 (i.e. [SHA1, nil, MD5] => [MD5, SHA1])
      assert_equal "message", roundtrip("message", coordinator["other salt"], md5_coordinator["other salt"])
      assert_equal "message", roundtrip("message", sha1_coordinator["other salt"], coordinator["other salt"])
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

    test "rotation options are deduped" do
      coordinator = make_coordinator
      coordinator.rotate(digest: "SHA1") # (3) Finally, everything upgraded to SHA1
      coordinator.rotate do |salt|       # (2) Then, one salt upgraded to SHA1
        { digest: "SHA1" } if salt == "salt"
      end
      coordinator.rotate(digest: "MD5")  # (1) Originally, everything used MD5

      rotated = 0
      coordinator.on_rotation { rotated += 1 }

      codec = coordinator["salt"]
      md5_codec = (make_coordinator.rotate(digest: "MD5"))["salt"]

      assert_equal "message", roundtrip("message", md5_codec, codec)
      assert_equal 1, rotated # SHA1 tried only once
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
  end
end
