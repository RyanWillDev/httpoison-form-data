defmodule FormData.Formatters.URLEncoded do
  @behaviour FormData.Formatters

  @type options     :: [] | [get: true] | [url: true]

  @type key         :: String.t
  @type value       :: String.t
  @type entry       :: {key, value}
  @type post        :: {:form, list(entry)}
  @type get         :: [params: list(entry)]
  @type url         :: String.t

  @type t           :: post | get | url

  @doc """
  Format a `stream` of key-value tuples for URL Encoded requests.

  Since URLEncoded parameters can be used in GET and POST requests, the
  `options` hash includes a `:get` option. The default output is valid form
  data for a call to `HTTPoison.post`. The output with the `:get` flag is valid
  data for a call to `HTTPoison.get`.

  If a different HTTP library is in use, or if the URL string needs to be
  modified, the `:url` flag can be set to output the proper URL string.

  ## Examples

      iex> FormData.Formatters.URLEncoded.output([{"Name", "Value"}, {"Name2", "Value2"}], [])
      {:form, [{"Name", "Value"}, {"Name2", "Value2"}]}

      iex> FormData.Formatters.URLEncoded.output([{"Name", "Value"}, {"Name2", "Value2"}], get: true)
      [params: [{"Name", "Value"}, {"Name2", "Value2"}]]

      iex> FormData.Formatters.URLEncoded.output([{"Name", "Value"}, {"Name2", "Value2"}], url: true)
      "?Name=Value&Name2=Value2"

  """
  @spec output(stream :: Enum.t, opts :: options) :: __MODULE__.t
  def output([], [url: true]), do: ""
  def output([], [get: true]), do: [params: []]
  def output([], _opts), do: {:form, []}
  def output(stream, [url: true]) do
    str = stream
      |> Stream.map(fn {name, value} ->
        name <> "=" <> value
      end)
      |> Enum.join("&")

    "?" <> str
  end
  def output(stream, [get: true]), do: [params: Enum.to_list(stream)]
  def output(stream, _opts), do: {:form, Enum.to_list(stream)}

end
