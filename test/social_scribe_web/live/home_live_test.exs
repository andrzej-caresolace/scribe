defmodule SocialScribeWeb.HomeLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import Mox

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

      # Mock calendar sync (called on connected mount via CalendarSyncronizer)
      # GoogleCalendarApi.list_events/4 takes (token, start_time, end_time, calendar_id)
      SocialScribe.GoogleCalendarApiMock
      |> stub(:list_events, fn _token, _start, _end, _cal_id -> {:ok, []} end)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders upcoming meetings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Upcoming Meetings"
    end

    test "shows page without errors when no events", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert is_binary(html)
      assert html =~ "Upcoming Meetings"
    end
  end
end
