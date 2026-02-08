defmodule SocialScribe.AccountsSalesforceTest do
  @moduledoc "Tests for Salesforce-specific Accounts functions."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures
  alias SocialScribe.Accounts

  describe "find_or_create_salesforce_credential/2" do
    test "creates a new credential when none exists" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        provider: "salesforce",
        uid: "sf_user_001",
        token: "sf_access_token",
        refresh_token: "sf_refresh_token",
        instance_url: "https://myorg.salesforce.com",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
        email: "user@myorg.com"
      }

      assert {:ok, credential} = Accounts.find_or_create_salesforce_credential(user, attrs)
      assert credential.provider == "salesforce"
      assert credential.uid == "sf_user_001"
      assert credential.instance_url == "https://myorg.salesforce.com"
      assert credential.token == "sf_access_token"
      assert credential.refresh_token == "sf_refresh_token"
    end

    test "updates an existing credential" do
      user = user_fixture()
      _cred = make_salesforce_cred(%{user_id: user.id, uid: "sf_existing"})

      new_attrs = %{
        user_id: user.id,
        provider: "salesforce",
        uid: "sf_existing",
        token: "sf_new_token",
        refresh_token: "sf_new_refresh",
        instance_url: "https://updated.salesforce.com",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
        email: "user@updated.com"
      }

      assert {:ok, updated} = Accounts.find_or_create_salesforce_credential(user, new_attrs)
      assert updated.token == "sf_new_token"
      assert updated.instance_url == "https://updated.salesforce.com"
    end
  end

  describe "get_user_salesforce_credential/1" do
    test "returns the Salesforce credential for a user" do
      user = user_fixture()
      cred = make_salesforce_cred(%{user_id: user.id})

      found = Accounts.get_user_salesforce_credential(user.id)
      assert found.id == cred.id
      assert found.provider == "salesforce"
    end

    test "returns nil when user has no Salesforce credential" do
      user = user_fixture()
      assert is_nil(Accounts.get_user_salesforce_credential(user.id))
    end
  end

  describe "update_salesforce_credential_tokens/2" do
    test "updates token and instance_url" do
      user = user_fixture()
      cred = make_salesforce_cred(%{user_id: user.id})

      response = %{
        "access_token" => "brand_new_token",
        "instance_url" => "https://refreshed.salesforce.com"
      }

      assert {:ok, updated} = Accounts.update_salesforce_credential_tokens(cred, response)
      assert updated.token == "brand_new_token"
      assert updated.instance_url == "https://refreshed.salesforce.com"
    end
  end

  describe "list_user_credentials/2 with salesforce" do
    test "lists only Salesforce credentials" do
      user = user_fixture()
      _sf_cred = make_salesforce_cred(%{user_id: user.id})
      _hub_cred = hubspot_credential_fixture(%{user_id: user.id})

      sf_creds = Accounts.list_user_credentials(user, provider: "salesforce")
      assert length(sf_creds) == 1
      assert hd(sf_creds).provider == "salesforce"
    end
  end
end
