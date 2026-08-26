module Api
  module V1
    class UsersController < ApplicationController
      DEFAULT_LIMIT = 500
      MAX_LIMIT = 1000

      # GET /api/v1/users/slow
      #
      # Endpoint PROPOSITALMENTE ruim: para cada user, acessar `user.company.name`
      # dispara uma query adicional (N+1 queries), porque a associação :company
      # não foi carregada com includes/preload/eager_load/joins.
      #
      # No log do Rails isso aparece como:
      #   User Load ...
      #   Company Load ...
      #   Company Load ...
      #   Company Load ...
      #   (uma query de Company por usuário)
      def slow
        users = User.limit(query_limit)

        render json: users.map { |user| serialize(user) }
      end

      # GET /api/v1/users/fast
      #
      # Mesma resposta do /slow, porém resolve o N+1 com eager loading:
      # uma única query extra para carregar todas as companies necessárias,
      # em vez de uma query por usuário.
      def fast
        users = User.includes(:company).limit(query_limit)

        render json: users.map { |user| serialize(user) }
      end

      private

      def serialize(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          company: user.company.name
        }
      end

      def query_limit
        limit = params[:limit].to_i
        limit = DEFAULT_LIMIT if limit <= 0
        [ limit, MAX_LIMIT ].min
      end
    end
  end
end
