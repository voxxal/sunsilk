defmodule SunsilkWeb.HelloController do
  use SunsilkWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
