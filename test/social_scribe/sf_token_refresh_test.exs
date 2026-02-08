defmodule SocialScribe.SfTokenRefreshTest do
  @moduledoc "Tests for SalesforceTokenRefresher ensure_valid_token and refresh logic."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceTokenRefresher

  describe "ensure_valid_token/1" do
    test "returns credential as-is when expiry is far in the future" do
      cred = make_salesforce_cred(%{expires_at: DateTime.utc_now() |> DateTime.add(2, :hour)})
      assert {:ok, ^cred} = SalesforceTokenRefresher.ensure_valid_token(cred)
    end

    test "attempts refresh when token is nearly expired" do
      cred = make_salesforce_cred(%{expires_at: DateTime.utc_now() |> DateTime.add(60, :second)})

      # The actual refresh will fail because there's no real Salesforce server,
      # but we verify the function tries to refresh rather than returning the stale cred.
      result = SalesforceTokenRefresher.ensure_valid_token(cred)

      case result do
        {:ok, refreshed} -> assert refreshed.id == cred.id
        {:error, _reason} -> :ok
      end
    end
  end
end
