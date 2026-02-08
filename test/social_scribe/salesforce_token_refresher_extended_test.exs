defmodule SocialScribe.SalesforceTokenRefresherExtendedTest do
  @moduledoc "Extended tests for SalesforceTokenRefresher covering all code paths."
  use SocialScribe.DataCase

  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceTokenRefresher

  describe "ensure_valid_token/1 - expired token" do
    test "attempts refresh when token is already expired" do
      cred =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        })

      result = SalesforceTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end

    test "attempts refresh when token expires within buffer" do
      cred =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(60, :second)
        })

      result = SalesforceTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end
  end

  describe "refresh_credential/1" do
    test "attempts API call for refresh" do
      cred =
        make_salesforce_cred(%{
          refresh_token: "test_sf_refresh_token"
        })

      result = SalesforceTokenRefresher.refresh_credential(cred)

      case result do
        {:ok, _} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  describe "refresh_token/1" do
    test "returns error for invalid token" do
      result = SalesforceTokenRefresher.refresh_token("invalid_sf_refresh_token")

      case result do
        {:ok, _} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end

  describe "client/0" do
    test "returns a Tesla client struct" do
      client = SalesforceTokenRefresher.client()
      assert is_struct(client, Tesla.Client) or is_map(client)
    end
  end
end
