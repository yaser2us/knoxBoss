defmodule AuthService.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :role, :string, default: "user", null: false
      add :is_active, :boolean, default: true, null: false
      add :email_verified, :boolean, default: false, null: false
      add :email_verified_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :last_login_ip, :string
      add :api_key, :string
      add :api_key_created_at, :utc_datetime
      add :password_reset_token, :string
      add :password_reset_expires_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:api_key])
    create unique_index(:users, [:password_reset_token])
    create unique_index(:users, [:email_verification_token])
    create index(:users, [:role])
    create index(:users, [:is_active])
    create index(:users, [:email_verified])
    create index(:users, [:failed_login_attempts])
    create index(:users, [:last_login_at])
  end
end