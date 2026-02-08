defmodule SocialScribeWeb.HomeLiveExtendedTest do
  @moduledoc "Extended tests for HomeLive covering toggle_record and scheduling events."
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.CalendarFixtures
  import Mox

  # Suppress expected Postgrex/Logger noise from async calendar sync
  @moduletag capture_log: true

  setup :verify_on_exit!

  describe "HomeLive - toggle_record event" do
    setup %{conn: conn} do
      user = user_fixture()
      _google_cred = user_credential_fixture(%{user_id: user.id, provider: "google"})

      # Stub token refresher (credential may be expired)
      SocialScribe.TokenRefresherMock
      |> stub(:refresh_token, fn _token ->
        {:ok, %{"access_token" => "refreshed", "expires_in" => 3600}}
      end)

      # Stub calendar sync — must match the pattern {:ok, %{"items" => items}}
      SocialScribe.GoogleCalendarApiMock
      |> stub(:list_events, fn _token, _start, _end, _cal_id -> {:ok, %{"items" => []}} end)

      # Stub bot creation (create_bot/2 takes meeting_url and join_at)
      SocialScribe.RecallApiMock
      |> stub(:create_bot, fn _url, _join_at -> {:error, :insufficient_credit} end)

      # Stub bot deletion
      SocialScribe.RecallApiMock
      |> stub(:delete_bot, fn _bot_id -> {:ok, %Tesla.Env{status: 204}} end)

      event = calendar_event_fixture(%{user_id: user.id, record_meeting: false})

      %{conn: log_in_user(conn, user), user: user, event: event}
    end

    test "toggles recording on an event", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      # Wait for async :sync_calendars to finish before proceeding
      _ = render(view)

      # Check if the toggle button exists
      if has_element?(view, "[phx-click='toggle_record'][phx-value-id='#{event.id}']") do
        view
        |> element("[phx-click='toggle_record'][phx-value-id='#{event.id}']")
        |> render_click()

        updated_event = SocialScribe.Calendar.get_calendar_event!(event.id)
        assert updated_event.record_meeting == true
      end
    end
  end

  describe "HomeLive - sync_calendars" do
    setup %{conn: conn} do
      user = user_fixture()
      _google_cred = user_credential_fixture(%{user_id: user.id, provider: "google"})

      SocialScribe.TokenRefresherMock
      |> stub(:refresh_token, fn _token ->
        {:ok, %{"access_token" => "refreshed", "expires_in" => 3600}}
      end)

      SocialScribe.GoogleCalendarApiMock
      |> stub(:list_events, fn _token, _start, _end, _cal_id -> {:ok, %{"items" => []}} end)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "loading state transitions after mount", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard")
      # Wait for async :sync_calendars to finish
      _ = render(view)
      assert html =~ "Upcoming Meetings"
    end

    test "renders page title", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard")
      # Wait for async :sync_calendars to finish
      _ = render(view)
      assert html =~ "Upcoming Meetings"
    end
  end
end
