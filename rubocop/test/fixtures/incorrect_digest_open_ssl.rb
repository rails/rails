# frozen_string_literal: true

Digest
Digest::SHA1
Digest::SHA256.new
Digest::MD5.hexdigest(["test", "digest"]).join(":")
some_method(Digest::SHA256.new)
