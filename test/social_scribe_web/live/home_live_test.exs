defmodule SocialScribeWeb.HomeLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import Mox

  # Suppress expected log noise from async calendar sync
  @moduletag capture_log: true

  setup :verify_on_exit!

  describe "HomeLive - unauthenticated" do
    test "redirects when not logged in", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
      assert path == ~p"/users/log_in"
    end
  end

  describe "HomeLive - authenticated" do
    setup %{conn: conn} do
      user = user_fixture()

      # Stub token refresher in case credentials need refresh
      SocialScribe.TokenRefresherMock
      |> stub(:refresh_token, fn _token ->
        {:ok, %{"access_token" => "refreshed", "expires_in" => 3600}}
      end)

      # Mock calendar sync — must return %{"items" => [...]} to match CalendarSyncronizer with clause
      SocialScribe.GoogleCalendarApiMock
      |> stub(:list_events, fn _token, _start, _end, _cal_id -> {:ok, %{"items" => []}} end)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders upcoming meetings page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard")
      _ = render(view)

      assert html =~ "Upcoming Meetings"
    end

    test "shows page without errors when no events", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard")
      _ = render(view)

      assert is_binary(html)
      assert html =~ "Upcoming Meetings"
    end
  end
end
