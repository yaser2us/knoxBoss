defmodule AuthService.Accounts.User do
  @moduledoc """
  User schema with security features.
  
  This schema provides:
  - Secure password hashing with bcrypt
  - Account lockout functionality
  - Role-based access control
  - Audit trail fields
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias Bcrypt
  
  @derive {Jason.Encoder, only: [:id, :email, :first_name, :last_name, :roles, :permissions, :inserted_at, :updated_at]}
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :first_name, :string
    field :last_name, :string
    field :roles, {:array, :string}, default: []
    field :permissions, {:array, :string}, default: []
    field :failed_attempts, :integer, default: 0
    field :locked_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :email_verified, :boolean, default: false
    field :email_verification_token, :string
    field :password_reset_token, :string
    field :password_reset_sent_at, :utc_datetime
    field :profile_data, :map, default: %{}
    
    timestamps()
  end
  
  @doc """
  Changeset for user registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
    |> unique_constraint(:email)
    |> hash_password()
    |> generate_email_verification_token()
  end
  
  @doc """
  Changeset for user updates.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :roles, :permissions, :failed_attempts, :locked_at, :last_login_at, :email_verified, :profile_data])
    |> validate_email()
    |> unique_constraint(:email)
  end
  
  @doc """
  Changeset for password changes.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end
  
  @doc """
  Changeset for email verification.
  """
  def email_verification_changeset(user, attrs) do
    user
    |> cast(attrs, [:email_verified, :email_verification_token])
    |> validate_required([:email_verified])
  end
  
  @doc """
  Changeset for password reset.
  """
  def password_reset_changeset(user, attrs) do
    user
    |> cast(attrs, [:password_reset_token, :password_reset_sent_at])
    |> validate_required([:password_reset_token])
  end
  
  @doc """
  Basic changeset for general updates.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :roles, :permissions, :profile_data])
    |> validate_email()
    |> unique_constraint(:email)
  end
  
  # Private validation functions
  
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> update_change(:email, &String.downcase/1)
  end
  
  defp validate_password(changeset) do
    min_length = Application.get_env(:auth_service, :password_min_length, 8)
    
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: min_length)
    |> validate_format(:password, ~r/[a-z]/, message: "must contain at least one lowercase letter")
    |> validate_format(:password, ~r/[A-Z]/, message: "must contain at least one uppercase letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
    |> validate_format(:password, ~r/[^a-zA-Z0-9]/, message: "must contain at least one special character")
  end
  
  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      
      _ ->
        changeset
    end
  end
  
  defp generate_email_verification_token(changeset) do
    if changeset.valid? do
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
      put_change(changeset, :email_verification_token, token)
    else
      changeset
    end
  end
  
  @doc """
  Generate a password reset token.
  """
  def generate_password_reset_token(user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
    
    user
    |> password_reset_changeset(%{
      password_reset_token: token,
      password_reset_sent_at: DateTime.utc_now()
    })
  end
  
  @doc """
  Check if password reset token is valid (not expired).
  """
  def valid_password_reset_token?(user) do
    case user.password_reset_sent_at do
      nil ->
        false
      
      sent_at ->
        # Token expires after 1 hour
        DateTime.diff(DateTime.utc_now(), sent_at, :second) < 3600
    end
  end
  
  @doc """
  Get user's full name.
  """
  def full_name(user) do
    [user.first_name, user.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> user.email
      name -> name
    end
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
  Check if user account is locked.
  """
  def locked?(user) do
    case user.locked_at do
      nil ->
        false
      
      locked_at ->
        lockout_duration = Application.get_env(:auth_service, :lockout_duration, 900) # 15 minutes
        DateTime.diff(DateTime.utc_now(), locked_at, :second) < lockout_duration
    end
  end
  
  @doc """
  Get user display name.
  """
  def display_name(user) do
    case full_name(user) do
      nil -> user.email |> String.split("@") |> List.first()
      "" -> user.email |> String.split("@") |> List.first()
      name when name == user.email -> user.email |> String.split("@") |> List.first()
      name -> name
    end
  end
  
  @doc """
  Get user avatar URL (placeholder implementation).
  """
  def avatar_url(user) do
    # This could be extended to support actual avatar uploads
    # For now, we'll use Gravatar
    email_hash = 
      user.email
      |> String.trim()
      |> String.downcase()
      |> :crypto.hash(:md5)
      |> Base.encode16(case: :lower)
    
    "https://www.gravatar.com/avatar/#{email_hash}?d=identicon&s=200"
  end
  
  @doc """
  Check if user is admin.
  """
  def admin?(user) do
    has_role?(user, "admin")
  end
  
  @doc """
  Check if user can perform action.
  """
  def can?(user, action) do
    admin?(user) || has_permission?(user, action)
  end
end