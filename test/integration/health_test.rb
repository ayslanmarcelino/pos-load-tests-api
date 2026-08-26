require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /health retorna 200 e status ok" do
    get "/health"

    assert_response :success
    assert_equal({ "status" => "ok" }, JSON.parse(response.body))
  end
end
