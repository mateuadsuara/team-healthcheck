defmodule Backend.Router do
  {:ok, index_html} = File.read "../frontend/_build/index.html"
  @index_html index_html

  {:ok, favicon} = File.read "../frontend/html/favicon.ico"
  @favicon favicon

  use Plug.Router

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, @index_html)
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
    send_resp(conn, 200, Poison.encode!(res))
  end

  post "/register_point_of_view/:metric_name/:date/:person/:health/:slope" do
    {res, _} = PerspectivesServer.register_point_of_view(%{
      metric_name: metric_name,
      date: date,
      person: person,
      health: health,
      slope: slope
    })
    send_resp(conn, 200, Poison.encode!(res))
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end