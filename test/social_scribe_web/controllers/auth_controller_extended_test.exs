defmodule SocialScribeWeb.AuthControllerExtendedTest do
  @moduledoc "Extended tests for AuthController covering LinkedIn and failure paths."
  use SocialScribeWeb.ConnCase

  @moduletag capture_log: true

  import SocialScribe.AccountsFixtures

  describe "callback/2 - LinkedIn provider" do
    setup %{conn: conn} do
      user = user_fixture()

      auth = %Ueberauth.Auth{
        provider: :linkedin,
        uid: "li_#{System.unique_integer([:positive])}",
        info: %Ueberauth.Auth.Info{email: "linkedin@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "li_token",
          refresh_token: "li_refresh",
          expires_at: DateTime.to_unix(DateTime.add(DateTime.utc_now(), 3600, :second))
        },
        extra: %Ueberauth.Auth.Extra{
          raw_info: %{
            user: %{
              "sub" => "linkedin_sub_#{System.unique_integer([:positive])}"
            }
          }
        }
      }

      conn =
        conn
        |> log_in_user(user)
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)

      %{conn: conn, user: user}
    end

    test "creates LinkedIn credential and redirects to settings", %{conn: conn} do
      conn = get(conn, ~p"/auth/linkedin/callback", %{"provider" => "linkedin"})

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "LinkedIn"
    end
  end

  describe "callback/2 - Google OAuth Login (no current_user)" do
    test "redirects with error when no auth data present", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback", %{"provider" => "google"})

      # Ueberauth won't set ueberauth_auth without proper OAuth flow,
      # so it falls to the final callback which redirects with error
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "error"
    end
  end

  describe "callback/2 - failure path" do
    test "redirects with error when callback has no auth data", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "error"
    end
  end
end
