defmodule FormData.Mixfile do
  use Mix.Project

  def project do
    [app: :httpoison_form_data,
     version: "0.1.3",
     elixir: "~> 1.6",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     description: description(),
     deps: deps(),
     dialyzer: [ flags: [:unmatched_returns, :error_handling, :race_conditions, :underspecs] ]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: []]
  end

  defp description do
    """
    A library for building Multipart and URLEncoded structures from Elixir
    structures for HTTPoison and Hackney.
    """
  end

  defp package do
    [name: :httpoison_form_data,
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/spiceworks/httpoison-form-data"},
     maintainers: ["Spiceworks, Inc.", "asonix.dev@gmail.com"]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:httpoison, "~> 1.0", only: :test}, # In the event you aren't using HTTPoison
     {:ex_doc, ">= 0.0.0", only: :dev},
     {:bypass, "~> 0.8", only: :test},
     {:dialyxir, "~> 0.5", only: :dev, runtime: false}]
  end
end
