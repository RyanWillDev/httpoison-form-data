defmodule FormData do
  @moduledoc """
  This module contains the recursive traversal algorithm used to build properly
  formatted names for both multipart and urlencoded requests.
  """

  @type input_type :: keyword | map | struct
  @type payload :: FormData.Formatters.Multipart.t | FormData.Formatters.URLEncoded.t

  defmodule Error do
    @moduledoc """
    This is the generic FormData error. It should only be triggered when the
    data passed in is not a Keyword List, Map, or Struct.
    """
    defexception [:message]

    def exception(value) do
      msg = "expected Struct, Map, or Keyword, got: #{inspect value}"
      %__MODULE__{message: msg}
    end
  end

  defmodule File do
    @type t :: %__MODULE__{path: String.t}

    defstruct path: ""

    @doc """
    Create a new File struct containing the path specified

    Addition based on suprafly's (https://github.com/suprafly) fork for northofsummer.
    """
    @spec new(path :: String.t) :: File.t
    def new(path) do
      %__MODULE__{path: path}
    end
  end

  @formatters %{
    multipart: FormData.Formatters.Multipart,
    url_encoded: FormData.Formatters.URLEncoded
  }

  @doc """
  This function chooses the correct `formatter` and uses it in conjunction with
  the recursive name-formatting algorithm to produce the desired data structure.

  The built-in formatters are Multipart and URLEncoded, but a 3rd-party
  formatter that is a behaviour of FormData.Formatter can be passed in as well.
  """
  @spec create(obj :: input_type, formatter :: module, output_opts :: keyword(boolean)) :: {:ok, payload} | {:error, String.t}
  def create(obj, formatter, output_opts \\ [])
  def create(obj, formatter, output_opts) when is_list(obj) or is_map(obj) do
    obj = try do
      ensure_keyword(obj) # Error in here if not a keyword list
    rescue
      _ -> {:error, Error.exception(obj)}
    end

    case obj do
      {:error, _}=error -> error
      _ -> {:ok, do_create(obj, formatter, output_opts)}
    end
  end
  def create(obj, _formatter, _output_opts) do
    {:error, Error.exception(obj)}
  end

  @doc """
  This function chooses the correct `formatter` and uses it in conjunction with
  the recursive name-formatting algorithm to produce the desired data structure.

  The built-in formatters are Multipart and URLEncoded, but a 3rd-party
  formatter that is a behaviour of FormData.Formatter can be passed in as well.
  """
  @spec create!(obj :: input_type, formatter :: module, output_opts :: keyword(boolean)) :: payload
  def create!(obj, formatter, output_opts \\ [])
  def create!(obj, formatter, output_opts) when is_list(obj) or is_map(obj) do
    obj = try do
      ensure_keyword(obj) # Error in here if not a keyword list
    rescue
      _ -> raise Error, obj
    end

    do_create(obj, formatter, output_opts)
  end
  def create!(obj, _formatter, _output_opts) do
    raise Error, obj
  end

  # do_create is the generic sequence of the logic in this project.
  # When do_create is called, we assume that `obj` is a Keyword List.
  # First, it determines the correct formatter to use, then it generates the
  # required data structure with to_form's recursive traversal with a chained
  # nil-removal filter (in the same pass because streams).
  #
  # Finally, it passes a stream of key-value pairs to the output formatter,
  # which will coerce this into any required format.
  defp do_create(obj, formatter, output_opts) do
    f = Map.get(@formatters, formatter) || formatter

    obj
    |> to_form
    |> Stream.filter(&not_nil(&1))
    |> f.output(output_opts)
  end

  # Ensure keyword attempts to coerce a map or list into a keyword list. If this
  # is not possible, it errors.
  defp ensure_keyword(list) when is_list(list) do
    Enum.map(list, fn {k, v} ->
      {k, v}
    end)
  end
  defp ensure_keyword(map) when is_map(map) do
    map
    |> Map.delete(:__struct__)
    |> Map.to_list
  end

  # this is the entry point. We start the to_form recursion by initializing each
  # name to an empty string. we call pair_to_form as the callback rather than
  # nested_pair_to_form because we don't want the names at this point to be in
  # brackets.
  #
  # input:          %{"key" => "value"}
  # recursing call: to_form("value", "key")
  #
  # input:          %{"key" => [ "value1", "value2" ]}
  # recursing call: to_form([ "value1", "value2" ], "key")
  defp to_form(obj) do
    Stream.flat_map(obj, &pair_to_form(&1, ""))
  end

  # when we encounter a File struct as a value, we have reached the max depth of
  # this tree, return the formatted data in an array. The array is important
  # because it is flat_map'd out of the array. This function must come before
  # the declaration of the is_map because structs will return true for is_map.
  defp to_form(%File{}=file, name) do
    [{name, file}]
  end

  # When we have a nested map, we want to call nested_pair_to_form on each
  # key/value pair.
  #
  # input:          %{"key" => "value"}, "outer_key"
  # recursing call: to_form("value", "outer_key[key]")
  defp to_form(obj, name) when is_map(obj) do
    obj
    |> ensure_keyword
    |> Stream.flat_map(&nested_pair_to_form(&1, name))
  end

  # Tuples are converted to lists, since they behave similarly.
  defp to_form(obj, name) when is_tuple(obj) do
    Tuple.to_list(obj)
    |> to_form(name)
  end

  # Lists are simply iterated across. We append `[]` to the name provided.
  #
  # input:          ["value1", "value2", "value3"], "outer_key",
  # recursing call: [to_form("value1", "outer_key[]"),
  #                  to_form("value2", "outer_key[]"),
  #                  to_form("value3", "outer_key[]")]
  defp to_form(obj, name) when is_list(obj) do
    Stream.flat_map(obj, &to_form(&1, name <> "[]"))
  end

  # When we have a value that does not fit the above conditions, we assume
  # we have reached a value that is not a nested data structure and therefore
  # can safely return it.
  defp to_form(value, name) do
    [{name, value}]
  end

  defp pair_to_form({k, v}, name) do
    to_form(v, name <> "#{k}")
  end

  defp nested_pair_to_form({k, v}, name) do
    to_form(v, name <> "[#{k}]")
  end

  defp not_nil(nil), do: false
  defp not_nil({nil, _}), do: false
  defp not_nil({_, nil}), do: false
  defp not_nil(_), do: true

end
