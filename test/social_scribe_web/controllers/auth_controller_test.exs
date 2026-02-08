defmodule SocialScribeWeb.AuthControllerTest do
  @moduledoc "Tests for OAuth callback handlers in AuthController."
  use SocialScribeWeb.ConnCase

  @moduletag capture_log: true

  import SocialScribe.AccountsFixtures

  describe "callback/2 - generic fallback (no ueberauth_auth)" do
    test "redirects with error flash when no auth data", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "error"
    end
  end

  describe "callback/2 - Google provider (logged-in user)" do
    setup %{conn: conn} do
      user = user_fixture()

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google_#{System.unique_integer([:positive])}",
        info: %Ueberauth.Auth.Info{email: "google@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "google_token",
          refresh_token: "google_refresh",
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600, :second))
        }
      }

      conn =
        conn
        |> log_in_user(user)
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)

      %{conn: conn, user: user, auth: auth}
    end

    test "creates credential and redirects to settings", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback", %{"provider" => "google"})

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Google account added"
    end
  end

  describe "callback/2 - HubSpot provider (logged-in user)" do
    setup %{conn: conn} do
      user = user_fixture()

      auth = %Ueberauth.Auth{
        provider: :hubspot,
        uid: "hub_#{System.unique_integer([:positive])}",
        info: %Ueberauth.Auth.Info{email: "hub@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "hubspot_tok",
          refresh_token: "hubspot_ref",
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600, :second))
        }
      }

      conn =
        conn
        |> log_in_user(user)
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)

      %{conn: conn, user: user, auth: auth}
    end

    test "creates HubSpot credential and redirects to settings", %{conn: conn} do
      conn = get(conn, ~p"/auth/hubspot/callback", %{"provider" => "hubspot"})

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "HubSpot"
    end
  end

  describe "callback/2 - Salesforce provider (logged-in user)" do
    setup %{conn: conn} do
      user = user_fixture()

      auth = %Ueberauth.Auth{
        provider: :salesforce,
        uid: "sf_#{System.unique_integer([:positive])}",
        info: %Ueberauth.Auth.Info{email: "sf@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "salesforce_tok",
          refresh_token: "salesforce_ref",
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600, :second)),
          other: %{instance_url: "https://test.salesforce.com"}
        }
      }

      conn =
        conn
        |> log_in_user(user)
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)

      %{conn: conn, user: user, auth: auth}
    end

    test "creates Salesforce credential and redirects to settings", %{conn: conn} do
      conn = get(conn, ~p"/auth/salesforce/callback", %{"provider" => "salesforce"})

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce"
    end
  end

  describe "request/2" do
    test "renders request page", %{conn: conn} do
      # The request action typically redirects via Ueberauth plug,
      # but we can at least confirm it doesn't crash
      conn = get(conn, ~p"/auth/google")

      assert conn.status in [200, 302]
    end
  end
end
