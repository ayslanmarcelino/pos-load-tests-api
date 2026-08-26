class ApplicationController < ActionController::API
  # Adiciona headers de diagnóstico úteis durante a demonstração de teste de
  # carga: tempo de resposta e número aproximado de queries SQL executadas.
  # O objetivo principal continua sendo observar as queries no log do Rails;
  # os headers são só um atalho para quem estiver testando com curl/k6.
  around_action :measure_request

  private

  def measure_request
    query_count = 0

    counter = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      query_count += 1 unless payload[:name] == "SCHEMA"
    end

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)

    response.set_header("X-Response-Time", "#{elapsed_ms}ms")
    response.set_header("X-SQL-Queries", query_count.to_s)
  ensure
    ActiveSupport::Notifications.unsubscribe(counter) if counter
  end
end
