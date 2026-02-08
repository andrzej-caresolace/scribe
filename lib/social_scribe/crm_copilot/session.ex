defmodule SocialScribe.CrmCopilot.Session do
  @moduledoc "A copilot conversation session owned by a user."

  use Ecto.Schema
  import Ecto.Changeset

  schema "copilot_sessions" do
    field :label, :string

    belongs_to :user, SocialScribe.Accounts.User
    has_many :turns, SocialScribe.CrmCopilot.Turn, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  @required ~w(user_id)a
  @optional ~w(label)a

  def changeset(session, params) do
    session
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:user_id)
  end
end
