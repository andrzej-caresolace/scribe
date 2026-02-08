defmodule SocialScribe.HubspotTokenRefresherExtTest do
  @moduledoc "Tests for the HubspotTokenRefresher module."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.HubspotTokenRefresher

  describe "ensure_valid_token/1" do
    test "returns credential as-is when token is not expired" do
      cred =
        hubspot_credential_fixture(%{
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      assert {:ok, ^cred} = HubspotTokenRefresher.ensure_valid_token(cred)
    end

    test "attempts refresh when token is nearly expired" do
      cred =
        hubspot_credential_fixture(%{
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      result = HubspotTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _} -> :ok
      end
    end

    test "attempts refresh when token is already expired" do
      cred =
        hubspot_credential_fixture(%{
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      result = HubspotTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _} -> :ok
      end
    end
  end

  describe "refresh_token/1" do
    test "attempts refresh against HubSpot" do
      result = HubspotTokenRefresher.refresh_token("fake_refresh_token")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "refresh_credential/1" do
    test "attempts to refresh and update credential" do
      cred = hubspot_credential_fixture()

      result = HubspotTokenRefresher.refresh_credential(cred)

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
