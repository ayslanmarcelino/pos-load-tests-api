Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Health check leve usado como baseline nos testes de carga (ver load_tests/health.js).
  get "health" => "health#show"

  namespace :api do
    namespace :v1 do
      get "users/slow"
      get "users/fast"
    end
  end
end
