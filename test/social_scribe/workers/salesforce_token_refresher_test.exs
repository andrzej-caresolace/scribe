defmodule SocialScribe.Workers.SalesforceTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.SalesforceTokenRefresher

  describe "perform/1" do
    test "returns :ok when no credentials exist" do
      assert :ok = SalesforceTokenRefresher.perform(%Oban.Job{})
    end

    test "returns :ok when credentials exist but are not expiring soon" do
      # Create a credential with a far-future expiry
      _cred =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(7200, :second)
        })

      assert :ok = SalesforceTokenRefresher.perform(%Oban.Job{})
    end
  end
end
