defmodule AuthService.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :refresh_token, :string
      add :device_info, :map
      add :ip_address, :string
      add :user_agent, :string
      add :expires_at, :utc_datetime, null: false
      add :last_accessed_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false
      add :revoked_at, :utc_datetime
      add :revoked_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sessions, [:token])
    create unique_index(:sessions, [:refresh_token])
    create index(:sessions, [:user_id])
    create index(:sessions, [:expires_at])
    create index(:sessions, [:is_active])
    create index(:sessions, [:last_accessed_at])
    create index(:sessions, [:ip_address])
  end
end