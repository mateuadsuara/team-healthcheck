defmodule Backend.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get("/", do: send_resp(conn, 200, index_html()))
  match(_, do: send_resp(conn, 404, "Oops!"))

  def index_html() do
    {:ok, index_html} = File.read "../frontend/_build/index.html"
    index_html
  end
end
