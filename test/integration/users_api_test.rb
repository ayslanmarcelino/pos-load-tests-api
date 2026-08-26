require "test_helper"

class UsersApiTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/users/slow retorna 200" do
    get "/api/v1/users/slow"

    assert_response :success
  end

  test "GET /api/v1/users/fast retorna 200" do
    get "/api/v1/users/fast"

    assert_response :success
  end

  test "slow e fast retornam estruturas equivalentes" do
    get "/api/v1/users/slow", params: { limit: 10 }
    slow_body = JSON.parse(response.body)

    get "/api/v1/users/fast", params: { limit: 10 }
    fast_body = JSON.parse(response.body)

    assert_equal 10, slow_body.size
    assert_equal 10, fast_body.size
    assert_equal slow_body, fast_body
    assert_equal %w[company email id name], slow_body.first.keys.sort
  end

  test "limit padrao e 500" do
    get "/api/v1/users/slow"

    assert_equal 500, JSON.parse(response.body).size
  end

  test "limit maximo de 1000 e respeitado mesmo pedindo mais" do
    get "/api/v1/users/fast", params: { limit: 100_000 }

    assert_equal 1000, JSON.parse(response.body).size
  end

  test "fast executa menos queries que slow (resolve o N+1)" do
    get "/api/v1/users/slow", params: { limit: 20 }
    slow_queries = response.headers["X-SQL-Queries"].to_i

    get "/api/v1/users/fast", params: { limit: 20 }
    fast_queries = response.headers["X-SQL-Queries"].to_i

    assert_operator fast_queries, :<, slow_queries
  end
end
