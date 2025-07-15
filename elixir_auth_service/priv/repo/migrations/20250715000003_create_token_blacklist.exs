defmodule AuthService.Repo.Migrations.CreateTokenBlacklist do
  use Ecto.Migration

  def change do
    create table(:token_blacklist, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token_jti, :string, null: false
      add :token_type, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :expires_at, :utc_datetime, null: false
      add :reason, :string
      add :blacklisted_by, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:token_blacklist, [:token_jti])
    create index(:token_blacklist, [:user_id])
    create index(:token_blacklist, [:expires_at])
    create index(:token_blacklist, [:token_type])
    create index(:token_blacklist, [:inserted_at])
  end
end