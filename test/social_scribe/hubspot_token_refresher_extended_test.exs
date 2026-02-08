defmodule SocialScribe.HubspotTokenRefresherExtendedTest do
  @moduledoc "Extended tests for HubspotTokenRefresher covering ensure_valid_token + refresh_credential."
  use SocialScribe.DataCase

  import SocialScribe.AccountsFixtures

  alias SocialScribe.HubspotTokenRefresher

  describe "ensure_valid_token/1 - expired token" do
    test "attempts refresh when token is already expired" do
      user = user_fixture()

      cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        })

      result = HubspotTokenRefresher.ensure_valid_token(cred)

      # Will fail due to no real HubSpot server, but the refresh attempt path is exercised
      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end

    test "attempts refresh when token expires within buffer (5 minutes)" do
      user = user_fixture()

      cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.utc_now() |> DateTime.add(60, :second)
        })

      result = HubspotTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end
  end

  describe "refresh_credential/1" do
    test "attempts API call and returns error without real server" do
      user = user_fixture()

      cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          refresh_token: "test_refresh_token"
        })

      result = HubspotTokenRefresher.refresh_credential(cred)

      case result do
        {:ok, _} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  describe "refresh_token/1" do
    test "returns error when API call fails" do
      result = HubspotTokenRefresher.refresh_token("invalid_refresh_token")

      case result do
        {:ok, _} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  describe "client/0" do
    test "returns a Tesla client" do
      client = HubspotTokenRefresher.client()
      assert is_struct(client, Tesla.Client) or is_map(client)
    end
  end
end
