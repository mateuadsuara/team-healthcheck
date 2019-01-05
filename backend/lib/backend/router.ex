defmodule Backend.Router do
  {:ok, index_html} = File.read "../frontend/_build/index.html"
  @index_html index_html

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, @index_html)
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
