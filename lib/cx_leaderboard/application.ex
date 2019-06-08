defmodule CxLeaderboard.Application do
  use Application

  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      {Redix, name: :redix}
    ]

    opts = [strategy: :one_for_one, name: CxLeaderboard.Supervisor]
    result = Supervisor.start_link(children, opts)
  end
end
