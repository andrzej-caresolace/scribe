defmodule SocialScribe.Repo.Migrations.SetupCopilotTables do
  use Ecto.Migration

  def change do
    create table(:copilot_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :label, :string

      timestamps(type: :utc_datetime)
    end

    create index(:copilot_sessions, [:user_id])

    create table(:copilot_turns) do
      add :session_id, references(:copilot_sessions, on_delete: :delete_all), null: false
      add :sender, :string, null: false
      add :body, :text, null: false
      add :extras, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:copilot_turns, [:session_id])
  end
end
