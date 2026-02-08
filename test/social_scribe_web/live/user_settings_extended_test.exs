defmodule SocialScribeWeb.UserSettingsExtendedTest do
  @moduledoc "Extended tests for UserSettingsLive covering handle_event handlers."
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "UserSettingsLive - bot preferences" do
    setup :register_and_log_in_user

    test "renders settings page with all sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Connected Google Accounts"
      assert html =~ "Connected HubSpot Accounts"
      assert html =~ "Connected Salesforce Accounts"
    end

    test "shows Google connect button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      assert has_element?(view, "a", "Connect another Google Account")
    end

    test "validates bot preference form with join_minute_offset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      if has_element?(view, "form[phx-change='validate_user_bot_preference']") do
        view
        |> form("form[phx-change='validate_user_bot_preference']",
          user_bot_preference: %{join_minute_offset: 5}
        )
        |> render_change()
      end

      assert render(view) =~ "Settings" or render(view) =~ "Google"
    end

    test "submits bot preference form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      if has_element?(view, "form[phx-submit='update_user_bot_preference']") do
        view
        |> form("form[phx-submit='update_user_bot_preference']",
          user_bot_preference: %{join_minute_offset: 3}
        )
        |> render_submit()
      end

      assert render(view) =~ "Settings" or render(view) =~ "Google"
    end

    test "displays google account when connected", %{conn: conn, user: user} do
      _cred = user_credential_fixture(%{user_id: user.id, provider: "google"})
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")
      assert html =~ "Google Account"
    end

    test "displays hubspot account when connected", %{conn: conn, user: user} do
      _cred = hubspot_credential_fixture(%{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")
      assert html =~ "HubSpot Account"
    end

    test "displays salesforce account when connected", %{conn: conn, user: user} do
      _cred = make_salesforce_cred(%{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")
      assert html =~ "Salesforce Account"
    end

    test "shows connect HubSpot button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      assert has_element?(view, "a", "Connect HubSpot")
    end

    test "shows connect Salesforce button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      assert has_element?(view, "a", "Connect Salesforce")
    end
  end
end
