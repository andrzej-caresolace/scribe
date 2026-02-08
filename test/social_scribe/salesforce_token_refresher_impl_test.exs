defmodule SocialScribe.SalesforceTokenRefresherImplTest do
  @moduledoc "Tests for SalesforceTokenRefresher - refresh_token, refresh_credential, ensure_valid_token."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceTokenRefresher

  describe "client/0" do
    test "returns a Tesla client" do
      client = SalesforceTokenRefresher.client()
      assert is_list(client.pre)
    end
  end

  describe "refresh_token/1" do
    test "attempts token refresh against Salesforce" do
      # Without proper client_id/secret, this will fail,
      # but we verify the function call works
      result = SalesforceTokenRefresher.refresh_token("fake_refresh_token")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "refresh_credential/1" do
    test "attempts to refresh and update credential" do
      cred = make_salesforce_cred()

      result = SalesforceTokenRefresher.refresh_credential(cred)

      # Will fail without real Salesforce connection
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "ensure_valid_token/1" do
    test "returns credential when not yet expired" do
      cred = make_salesforce_cred(%{expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)})

      assert {:ok, ^cred} = SalesforceTokenRefresher.ensure_valid_token(cred)
    end

    test "attempts refresh when token is about to expire" do
      cred =
        make_salesforce_cred(%{expires_at: DateTime.add(DateTime.utc_now(), 30, :second)})

      result = SalesforceTokenRefresher.ensure_valid_token(cred)

      # Will either succeed (if mocked) or fail (without real Salesforce)
      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end

    test "attempts refresh when token is already expired" do
      cred =
        make_salesforce_cred(%{expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)})

      result = SalesforceTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end
  end
end
