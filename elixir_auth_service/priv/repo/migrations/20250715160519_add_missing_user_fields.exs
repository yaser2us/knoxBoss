defmodule AuthService.Repo.Migrations.AddMissingUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Add missing fields that the User model expects
      add :roles, {:array, :string}, default: []
      add :permissions, {:array, :string}, default: []
      add :profile_data, :map, default: %{}
      
      # Rename failed_login_attempts to failed_attempts to match the model
      add :failed_attempts, :integer, default: 0
      
      # Add missing fields that the model expects
      add :password_reset_sent_at, :utc_datetime
    end
    
    # Copy data from old column to new column
    execute "UPDATE users SET failed_attempts = failed_login_attempts", ""
    
    # Drop the old column
    alter table(:users) do
      remove :failed_login_attempts
    end
    
    # Update indexes
    create index(:users, [:failed_attempts])
    create index(:users, [:roles])
    create index(:users, [:permissions])
  end
end