defmodule FormData.Formatters.Multipart do
  @behaviour FormData.Formatters

  @type entry_type    :: String.t | :file
  @type path_value    :: String.t
  @type form_data     :: String.t
  @type name_key      :: String.t
  @type name          :: String.t
  @type filename_key  :: String.t
  @type filename      :: String.t
  @type key_metadata  :: { name_key, name }
  @type file_metadata :: { filename_key, filename }
  @type metadata      :: file_metadata | key_metadata
  @type entry         :: { entry_type, path_value, { form_data, nonempty_list(metadata) }, [] }

  @type t             :: { :multipart, list(entry) }

  @doc """
  The Multipart output function wraps the output of `format` in a structure
  denoting to HTTPoison (and hackney) that the data to be submitted is
  multipart.

  ## Examples

      iex> FormData.Formatters.Multipart.output([{:key, "one"}], [])
      { :multipart, [{ "", "one", { "form-data", [ {"name", "\\"key\\""} ] }, [] }] }

  """
  @spec output(stream :: Stream.t, _opts :: any) :: __MODULE__.t
  def output(stream, _opts) do
    list = stream
      |> Stream.map(fn
        {k, %FormData.File{path: path}} -> format(k, path, true)
        {k, v} -> format(k, v, false)
      end)
      |> Enum.to_list

    {:multipart, list}
  end

  defp format(name, path, true) do
    filename = Path.basename(path)

    {
      :file,
      path,
      {
        "form-data",
        [
          {"name", "\"#{name}\""},
          {"filename", "\"#{filename}\""}
        ]
      },
      []
    }
  end
  defp format(name, value, false) do
    {
      "",
      value,
      {
        "form-data",
        [ {"name", "\"#{name}\""} ]
      },
      []
    }
  end

end
