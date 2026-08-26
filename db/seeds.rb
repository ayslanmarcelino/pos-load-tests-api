# Popula o banco com uma massa de dados suficiente para os testes de carga.
#
# ~500 companies e ~20_000 users, usando insert_all para manter o seed rápido
# (evita instanciar 20 mil ActiveRecord objects e disparar 20 mil INSERTs).
#
# Uso:
#   rails db:seed
#   docker compose exec web rails db:seed

COMPANIES_COUNT = 500
USERS_COUNT = 20_000

puts "Limpando dados existentes..."
User.delete_all
Company.delete_all

puts "Criando #{COMPANIES_COUNT} companies..."
now = Time.current

companies = (1..COMPANIES_COUNT).map do |i|
  { name: "Company #{i}", created_at: now, updated_at: now }
end

Company.insert_all(companies)

company_ids = Company.order(:id).pluck(:id)

puts "Criando #{USERS_COUNT} users..."

users = (1..USERS_COUNT).map do |i|
  {
    name: "User #{i}",
    email: "user#{i}@example.com",
    # Distribui os usuários entre as empresas de forma cíclica.
    company_id: company_ids[i % company_ids.size],
    created_at: now,
    updated_at: now
  }
end

users.each_slice(5_000) do |batch|
  User.insert_all(batch)
end

puts "Seed concluído: #{Company.count} companies, #{User.count} users."
