# Endpoint de baseline: usado para medir o desempenho do Rails/Puma
# fazendo o mínimo de trabalho possível (nenhuma query, nenhuma serialização).
class HealthController < ApplicationController
  def show
    render json: { status: "ok" }
  end
end
