# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/digest"

class DigestUUIDExt < ActiveSupport::TestCase
  def test_constants
    assert_equal "6ba7b810-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::DNS_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b811-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::URL_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b812-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::OID_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b814-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::X500_NAMESPACE.unpack("NnnnnN")
  end

  def test_v3_uuids_with_rfc4122_namespaced_uuids_enabled
    with_use_rfc4122_namespaced_uuids_set do
      assert_not_deprecated do
        assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
        assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
        assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")

        assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
        assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
        assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")

        assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
        assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
        assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3(Digest::UUID::OID_NAMESPACE, "1.2.3")

        assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
        assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
        assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
      end

      assert_raise ArgumentError do
        Digest::UUID.uuid_v3("A non-UUID string", "some value")
      end
    end
  end

  def test_v3_uuids_with_rfc4122_namespaced_uuids_disabled
    assert_deprecated do
      assert_equal "995e5d8e-364a-386e-8b3d-65d6a7d5478f", Digest::UUID.uuid_v3("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
    end

    assert_deprecated do
      assert_equal "fe5a52d1-703f-3326-b919-2d96003288f3", Digest::UUID.uuid_v3("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
    end

    assert_not_deprecated do
      assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")
    end

    assert_deprecated do
      assert_equal "1a27509f-2955-3d78-8f53-c92935fecc57", Digest::UUID.uuid_v3("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
    end

    assert_deprecated do
      assert_equal "2676127a-9073-36e3-b9db-14bc16b7c083", Digest::UUID.uuid_v3("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
    end

    assert_not_deprecated do
      assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")
    end

    assert_deprecated do
      assert_equal "2e2a2437-160c-36e7-952d-d6f494edea44", Digest::UUID.uuid_v3("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
    end

    assert_deprecated do
      assert_equal "719357e1-54f1-3930-8113-a1faffde48fa", Digest::UUID.uuid_v3("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
    end

    assert_not_deprecated do
      assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3(Digest::UUID::OID_NAMESPACE, "1.2.3")
    end

    assert_deprecated do
      assert_equal "01c2671b-fd20-3e43-8cff-217f40e110c8", Digest::UUID.uuid_v3("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_deprecated do
      assert_equal "32560c4a-c9f1-3974-9c1c-5e52761e091f", Digest::UUID.uuid_v3("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_not_deprecated do
      assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_deprecated do
      assert_equal "cd3d768f-7380-3d1f-8834-e034b40e65ea", Digest::UUID.uuid_v3("A non-UUID string", "some value")
    end
  end

  def test_v5_uuids_with_rfc4122_namespaced_uuids_enabled
    with_use_rfc4122_namespaced_uuids_set do
      assert_not_deprecated do
        assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
        assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
        assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")

        assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
        assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
        assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")

        assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
        assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
        assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "1.2.3")

        assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
        assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
        assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
      end

      assert_raise ArgumentError do
        Digest::UUID.uuid_v5("A non-UUID string", "some value")
      end
    end
  end

  def test_v5_uuids_with_rfc4122_namespaced_uuids_disabled
    assert_deprecated do
      assert_equal "442faf6c-4996-5266-aeef-ecadb5d49e54", Digest::UUID.uuid_v5("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
    end

    assert_deprecated do
      assert_equal "027963ef-431c-5670-ab2c-820168da74e9", Digest::UUID.uuid_v5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
    end

    assert_not_deprecated do
      assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")
    end

    assert_deprecated do
      assert_equal "59207e54-33c5-5914-ab39-b7f3333a0097", Digest::UUID.uuid_v5("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
    end

    assert_deprecated do
      assert_equal "d8e1e518-2337-58e5-bf52-6c563631db90", Digest::UUID.uuid_v5("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
    end

    assert_not_deprecated do
      assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")
    end

    assert_deprecated do
      assert_equal "72409eff-7406-5906-b86e-6c7a726ed04e", Digest::UUID.uuid_v5("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
    end

    assert_deprecated do
      assert_equal "b9b86653-48bb-5059-861a-2c72974b5c8d", Digest::UUID.uuid_v5("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
    end

    assert_not_deprecated do
      assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "1.2.3")
    end

    assert_deprecated do
      assert_equal "de6fe50e-eded-580a-81c9-f0774a3531da", Digest::UUID.uuid_v5("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_deprecated do
      assert_equal "e84a8a4e-a5c7-55b8-ad09-020c0b5662a7", Digest::UUID.uuid_v5("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_not_deprecated do
      assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    end

    assert_deprecated do
      assert_equal "b42d5423-1047-5bb3-afd4-0dec60fb22d2", Digest::UUID.uuid_v5("A non-UUID string", "some value")
    end
  end

  def test_invalid_hash_class
    assert_raise ArgumentError do
      Digest::UUID.uuid_from_hash(OpenSSL::Digest::SHA256, Digest::UUID::OID_NAMESPACE, "1.2.3")
    end
  end

  private
    def with_use_rfc4122_namespaced_uuids_set
      old_value = Digest::UUID.use_rfc4122_namespaced_uuids
      Digest::UUID.use_rfc4122_namespaced_uuids = true
      yield
    ensure
      Digest::UUID.use_rfc4122_namespaced_uuids = old_value
    end
end
