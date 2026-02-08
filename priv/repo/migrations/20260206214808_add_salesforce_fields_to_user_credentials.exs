defmodule SocialScribe.Repo.Migrations.AddSalesforceFieldsToUserCredentials do
  use Ecto.Migration

  def change do
    alter table(:user_credentials) do
      # Salesforce instance URL (e.g., https://na1.salesforce.com)
      # Required for making API calls to the correct Salesforce org
      add :instance_url, :string
    end
  end
end
