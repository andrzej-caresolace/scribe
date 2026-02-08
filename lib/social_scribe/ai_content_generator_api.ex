defmodule SocialScribe.AIContentGeneratorApi do
  @moduledoc """
  Behaviour for generating AI content for meetings.
  """

  @callback generate_follow_up_email(map()) :: {:ok, String.t()} | {:error, any()}
  @callback generate_automation(map(), map()) :: {:ok, String.t()} | {:error, any()}
  @callback generate_hubspot_suggestions(map()) :: {:ok, list(map())} | {:error, any()}
  @callback generate_salesforce_suggestions(map()) :: {:ok, list(map())} | {:error, any()}
  @callback compose_copilot_reply(binary(), map()) :: {:ok, binary()} | {:error, term()}

  def generate_follow_up_email(meeting), do: impl().generate_follow_up_email(meeting)

  def generate_automation(automation, meeting),
    do: impl().generate_automation(automation, meeting)

  def generate_hubspot_suggestions(meeting), do: impl().generate_hubspot_suggestions(meeting)

  def generate_salesforce_suggestions(meeting),
    do: impl().generate_salesforce_suggestions(meeting)

  def compose_copilot_reply(question, ctx), do: impl().compose_copilot_reply(question, ctx)

  defp impl do
    Application.get_env(
      :social_scribe,
      :ai_content_generator_api,
      SocialScribe.AIContentGenerator
    )
  end
end
