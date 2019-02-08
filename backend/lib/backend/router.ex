defmodule Backend.Router do
  {:ok, favicon} = File.read "../frontend/html/favicon.ico"
  @favicon favicon

  use Plug.Router

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:match)
  plug(:dispatch)

  get "/" do
    {:ok, index_html} = File.read "../frontend/_build/index.html"
    send_resp(conn, 200, index_html)
  end

  get "/favicon.ico" do
    send_resp(conn, 200, @favicon)
  end

  get "/graph" do
    send_resp(conn, 200, Poison.encode!(PerspectivesServer.graph))
  end

  post "/add_metric" do
    name = conn.params["name"]
    criteria = conn.params["criteria"]
    {res, _} = PerspectivesServer.add_metric(%{
      name: name,
      criteria: criteria
    })
    send_resp(conn |> put_resp_header("Location", "/"), 302, Poison.encode!(res))
  end

  post "/register_point_of_view" do
    metric_name = conn.params["metric_name"]
    date = conn.params["date"]
    person = conn.params["person"]
    {health, ""} = Integer.parse(conn.params["health"])
    {slope, ""} = Integer.parse(conn.params["slope"])
    {res, _} = PerspectivesServer.register_point_of_view(%{
      metric_name: metric_name,
      date: date,
      person: person,
      health: health,
      slope: slope
    })
    send_resp(conn |> put_resp_header("Location", "/"), 302, Poison.encode!(res))
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
