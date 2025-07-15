# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AuthService.Repo.insert!(%AuthService.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias AuthService.Repo
alias AuthService.Accounts.User

# Create a default admin user for development
admin_attrs = %{
  email: "admin@example.com",
  password: "admin123456",
  first_name: "Admin",
  last_name: "User",
  role: "admin",
  is_active: true,
  email_verified: true,
  email_verified_at: DateTime.utc_now()
}

case Repo.get_by(User, email: admin_attrs.email) do
  nil ->
    {:ok, admin} = User.create_changeset(%User{}, admin_attrs) |> Repo.insert()
    IO.puts("Created admin user: #{admin.email}")
  
  existing_user ->
    IO.puts("Admin user already exists: #{existing_user.email}")
end

# Create a default regular user for development
user_attrs = %{
  email: "user@example.com",
  password: "user123456",
  first_name: "Regular",
  last_name: "User",
  role: "user",
  is_active: true,
  email_verified: true,
  email_verified_at: DateTime.utc_now()
}

case Repo.get_by(User, email: user_attrs.email) do
  nil ->
    {:ok, user} = User.create_changeset(%User{}, user_attrs) |> Repo.insert()
    IO.puts("Created regular user: #{user.email}")
  
  existing_user ->
    IO.puts("Regular user already exists: #{existing_user.email}")
end

IO.puts("Database seeding completed!")