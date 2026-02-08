defmodule SocialScribeWeb.UserSettingsSalesforceTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "UserSettingsLive - Salesforce section" do
    setup :register_and_log_in_user

    test "shows Salesforce section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Connected Salesforce Accounts"
    end

    test "shows connect button when no Salesforce accounts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "a", "Connect Salesforce")
    end

    test "displays connected Salesforce account", %{conn: conn, user: user} do
      _cred = make_salesforce_cred(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Salesforce Account"
      refute html =~ "You haven't connected any Salesforce accounts yet."
    end

    test "shows HubSpot section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Connected HubSpot Accounts"
    end

    test "shows connect HubSpot button when none connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "a", "Connect HubSpot")
    end

    test "displays connected HubSpot account", %{conn: conn, user: user} do
      _cred = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "HubSpot Account"
    end
  end
end
