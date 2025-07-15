defmodule AuthService.Accounts do
  @moduledoc """
  The Accounts context for user management.
  
  This module provides:
  - User creation and authentication
  - Password hashing and verification
  - Account lockout and security features
  - User profile management
  """
  
  import Ecto.Query, warn: false
  alias AuthService.Repo
  alias AuthService.Accounts.User
  alias Bcrypt
  
  require Logger
  
  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end
  
  @doc """
  Gets a single user by ID.
  """
  def get_user!(id), do: Repo.get!(User, id)
  
  @doc """
  Gets a single user by ID (returns nil if not found).
  """
  def get_user(id), do: Repo.get(User, id)
  
  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: String.downcase(email))
  end
  
  @doc """
  Creates a user with secure password hashing.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        Logger.info("User created successfully", %{user_id: user.id, email: user.email})
        {:ok, user}
      
      {:error, changeset} ->
        Logger.error("User creation failed", %{errors: changeset.errors})
        {:error, changeset}
    end
  end
  
  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        Logger.info("User updated successfully", %{user_id: user.id})
        {:ok, user}
      
      {:error, changeset} ->
        Logger.error("User update failed", %{user_id: user.id, errors: changeset.errors})
        {:error, changeset}
    end
  end
  
  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
    |> case do
      {:ok, user} ->
        Logger.info("User deleted successfully", %{user_id: user.id})
        {:ok, user}
      
      {:error, changeset} ->
        Logger.error("User deletion failed", %{user_id: user.id, errors: changeset.errors})
        {:error, changeset}
    end
  end
  
  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
  
  @doc """
  Authenticate a user with email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)
    
    case user do
      nil ->
        # Still perform password check to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
      
      %User{locked_at: locked_at} = user when not is_nil(locked_at) ->
        if account_locked?(user) do
          {:error, :account_locked}
        else
          # Account lock expired, clear it
          {:ok, user} = update_user(user, %{locked_at: nil, failed_attempts: 0})
          verify_password(user, password)
        end
      
      user ->
        verify_password(user, password)
    end
  end
  
  @doc """
  Change user password.
  """
  def change_password(user, current_password, new_password) do
    if Bcrypt.verify_pass(current_password, user.password_hash) do
      user
      |> User.password_changeset(%{password: new_password})
      |> Repo.update()
      |> case do
        {:ok, user} ->
          Logger.info("Password changed successfully", %{user_id: user.id})
          {:ok, user}
        
        {:error, changeset} ->
          Logger.error("Password change failed", %{user_id: user.id, errors: changeset.errors})
          {:error, changeset}
      end
    else
      {:error, :invalid_current_password}
    end
  end
  
  @doc """
  Reset user password (admin function).
  """
  def reset_password(user, new_password) do
    user
    |> User.password_changeset(%{password: new_password})
    |> Repo.update()
    |> case do
      {:ok, user} ->
        Logger.info("Password reset successfully", %{user_id: user.id})
        {:ok, user}
      
      {:error, changeset} ->
        Logger.error("Password reset failed", %{user_id: user.id, errors: changeset.errors})
        {:error, changeset}
    end
  end
  
  @doc """
  Lock a user account.
  """
  def lock_account(user) do
    update_user(user, %{
      locked_at: DateTime.utc_now(),
      failed_attempts: 0
    })
    |> case do
      {:ok, user} ->
        Logger.warn("Account locked", %{user_id: user.id})
        {:ok, user}
      
      error ->
        error
    end
  end
  
  @doc """
  Unlock a user account.
  """
  def unlock_account(user) do
    update_user(user, %{
      locked_at: nil,
      failed_attempts: 0
    })
    |> case do
      {:ok, user} ->
        Logger.info("Account unlocked", %{user_id: user.id})
        {:ok, user}
      
      error ->
        error
    end
  end
  
  @doc """
  Update user roles.
  """
  def update_user_roles(user, roles) do
    update_user(user, %{roles: roles})
  end
  
  @doc """
  Update user permissions.
  """
  def update_user_permissions(user, permissions) do
    update_user(user, %{permissions: permissions})
  end
  
  @doc """
  Check if user has a specific role.
  """
  def has_role?(user, role) do
    role in (user.roles || [])
  end
  
  @doc """
  Check if user has a specific permission.
  """
  def has_permission?(user, permission) do
    permission in (user.permissions || [])
  end
  
  @doc """
  Get user analytics.
  """
  def get_user_analytics(user) do
    %{
      id: user.id,
      email: user.email,
      created_at: user.inserted_at,
      last_login: user.last_login_at,
      failed_attempts: user.failed_attempts,
      locked: not is_nil(user.locked_at),
      roles: user.roles || [],
      permissions: user.permissions || []
    }
  end
  
  # Private Functions
  
  defp verify_password(user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      # Reset failed attempts on successful login
      {:ok, user} = update_user(user, %{
        failed_attempts: 0,
        last_login_at: DateTime.utc_now()
      })
      
      Logger.info("User authenticated successfully", %{user_id: user.id})
      {:ok, user}
    else
      # Increment failed attempts
      new_attempts = (user.failed_attempts || 0) + 1
      max_attempts = Application.get_env(:auth_service, :max_login_attempts, 5)
      
      if new_attempts >= max_attempts do
        # Lock the account
        {:ok, _user} = lock_account(user)
        {:error, :account_locked}
      else
        # Update failed attempts
        {:ok, _user} = update_user(user, %{failed_attempts: new_attempts})
        {:error, :invalid_credentials}
      end
    end
  end
  
  defp account_locked?(user) do
    case user.locked_at do
      nil ->
        false
      
      locked_at ->
        lockout_duration = Application.get_env(:auth_service, :lockout_duration, 900) # 15 minutes
        DateTime.diff(DateTime.utc_now(), locked_at, :second) < lockout_duration
    end
  end
end