defmodule Backend.Router do
  {:ok, index_html} = File.read "../frontend/_build/index.html"
  @index_html index_html

  {:ok, favicon} = File.read "../frontend/html/favicon.ico"
  @favicon favicon

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, @index_html)
  end

  get "/favicon.ico" do
    send_resp(conn, 200, @favicon)
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
