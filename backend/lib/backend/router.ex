defmodule Backend.Router do
  {:ok, favicon} = File.read "../frontend/html/favicon.ico"
  @favicon favicon

  use Plug.Router

  plug(Plug.Parsers, parsers: [:urlencoded, :multipart])
  plug(:match)
  plug(:dispatch)

  get "/" do
    {:ok, index_html} = File.read "../frontend/_build/index.html"
    send_resp(conn, 200, index_html)
  end

  get "/favicon.ico" do
    send_resp(conn, 200, @favicon)
  end

  get "/snapshot" do
    snapshot = %{graph: PerspectivesServer.graph}
               |> Map.merge(ClientsCoordinationServer.get_state)
    send_resp(conn, 200, Poison.encode!(snapshot))
  end

  get "/serialise" do
    send_resp(conn, 200, Poison.encode!(PerspectivesServer.serialise))
  end

  post "/deserialise" do
    serialised_file = conn.params["serialised"]
    {:ok, serialised_json} = File.read serialised_file.path
    {res, _} = serialised_json
               |> Poison.decode!(%{keys: :atoms!})
               |> PerspectivesServer.deserialise

    broadcast_ws(%{updatedGraph: PerspectivesServer.graph})

    send_resp(conn |> put_resp_header("location", "/"), 302, Poison.encode!(res))
  end

  post "/add_metric" do
    name = conn.params["name"]
    criteria = conn.params["criteria"]
    {res, _} = PerspectivesServer.add_metric(%{
      name: name,
      criteria: criteria
    })

    broadcast_ws(%{updatedGraph: PerspectivesServer.graph})

    send_resp(conn |> put_resp_header("location", "/"), 302, Poison.encode!(res))
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

    broadcast_ws(%{updatedGraph: PerspectivesServer.graph})

    send_resp(conn |> put_resp_header("location", "/"), 302, Poison.encode!(res))
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end

  def broadcast_ws(data) do
    json = Poison.encode!(data)
    Registry.SocketHandler
    |> Registry.dispatch("broadcast", fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, {:text, json}, [])
      end
    end)
  end
end
