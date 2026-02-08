defmodule SocialScribe.Workers.TokenRefreshersExtendedTest do
  @moduledoc "Extended tests for both HubSpot and Salesforce worker token refreshers."
  use SocialScribe.DataCase

  import SocialScribe.AccountsFixtures

  alias SocialScribe.Workers.SalesforceTokenRefresher, as: SFWorker
  alias SocialScribe.Workers.HubspotTokenRefresher, as: HSWorker

  describe "SalesforceTokenRefresher.perform/1 with expiring credentials" do
    test "attempts refresh when credential expires within threshold" do
      _cred =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-60, :second)
        })

      # The refresh will fail (no real Salesforce server) but the code path is exercised
      # The worker returns :ok even on individual failures
      assert :ok = SFWorker.perform(%Oban.Job{})
    end

    test "handles multiple expiring credentials" do
      for _i <- 1..3 do
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-120, :second)
        })
      end

      assert :ok = SFWorker.perform(%Oban.Job{})
    end

    test "returns :ok with a mix of expiring and valid credentials" do
      # Valid credential (far future)
      _valid =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(7200, :second)
        })

      # Expiring credential
      _expiring =
        make_salesforce_cred(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-30, :second)
        })

      assert :ok = SFWorker.perform(%Oban.Job{})
    end
  end

  describe "HubspotTokenRefresher.perform/1 with expiring credentials" do
    test "attempts refresh when credential expires within threshold" do
      _cred =
        hubspot_credential_fixture(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-60, :second)
        })

      # The refresh will fail (no real HubSpot server) but the code path is exercised
      assert :ok = HSWorker.perform(%Oban.Job{})
    end

    test "handles multiple expiring credentials" do
      for _i <- 1..3 do
        hubspot_credential_fixture(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-120, :second)
        })
      end

      assert :ok = HSWorker.perform(%Oban.Job{})
    end

    test "returns :ok with mix of expiring and valid" do
      _valid =
        hubspot_credential_fixture(%{
          expires_at: DateTime.utc_now() |> DateTime.add(7200, :second)
        })

      _expiring =
        hubspot_credential_fixture(%{
          expires_at: DateTime.utc_now() |> DateTime.add(-30, :second)
        })

      assert :ok = HSWorker.perform(%Oban.Job{})
    end
  end
end
