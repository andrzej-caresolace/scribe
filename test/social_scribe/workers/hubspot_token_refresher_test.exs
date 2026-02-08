defmodule SocialScribe.Workers.HubspotTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.HubspotTokenRefresher

  describe "perform/1" do
    test "returns :ok when no credentials exist" do
      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end

    test "returns :ok when credentials are not expiring soon" do
      _cred =
        hubspot_credential_fixture(%{
          expires_at: DateTime.utc_now() |> DateTime.add(7200, :second)
        })

      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end
  end
end
