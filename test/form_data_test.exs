defmodule FormDataTest do
  use ExUnit.Case
 doctest FormData

 defmodule FormDataTest.NameFormatter do
   @behaviour FormData.Formatters
   def output(stream, _opts) do
     stream
     |> Stream.map(&format(&1))
     |> Enum.to_list
   end

   defp format({name, _value}), do: "#{name}"
 end

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass, url: "http://localhost:#{bypass.port}/"}
  end

  def prepare_conn(conn) do
    parsers_opts = [parsers: [:json, :multipart, :urlencoded]]
      |> Plug.Parsers.init
    conn
    |> Plug.Conn.fetch_query_params
    |> Plug.Parsers.call(parsers_opts)
    |> Plug.Conn.resp(200, "")
  end

  def assert_request(conn, href, verb, params, headers) do
    conn = prepare_conn(conn)

    assert href == conn.request_path
    assert verb == conn.method

    if params, do: assert params == conn.params

    headers |> Enum.each(fn header ->
      assert header in conn.req_headers
    end)

    conn
  end

  def assert_upload(%Plug.Upload{} = upload, filename, content_type) do
    assert upload.filename == filename
    assert upload.content_type == content_type
  end
  def assert_upload(_upload, _filename, _content_type), do: flunk("Structure was not an upload")

  defmodule TestStruct do
    defstruct name: "Default"
  end

  test "create allows custom formatters" do
    {:ok, result} = FormData.create([valid: "valid"], FormDataTest.NameFormatter)

    assert result == ["valid"]
  end

  test "create from struct works", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      assert_request(
        conn,
        "/",
        "POST",
        %{
          "name" => "MyName"
        },
        []
      )
    end

    {:ok, multipart} =
      %TestStruct{name: "MyName"}
      |> FormData.create(:multipart)

    HTTPoison.post(url, multipart, %{})
  end

  test "create with :multipart correctly formats nested data", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      assert_request(
        conn,
        "/",
        "POST",
        %{
          "one" => %{
            "sub_one" => "test",
            "sub_two" => "test"
          },
          "two" => [ "test", "test", "test" ],
          "three" => [ "test", "test", "test" ],
          "four" => %{
            "sub_one" => "test",
            "sub_two" => %{
              "sub_sub_one" => "test",
              "sub_sub_two" => [ "test", "test", "test" ]
            }
          }
        },
        []
      )
    end

    {:ok, multipart} = %{
      one: %{
        sub_one: "test",
        sub_two: "test"
      },
      two: [ "test", "test", "test" ],
      three: { "test", "test", "test" },
      four: %{
        sub_one: "test",
        sub_two: %{
          sub_sub_one: "test",
          sub_sub_two: [ "test", "test", "test" ]
        }
      }
    } |> FormData.create(:multipart)

    HTTPoison.post(url, multipart, %{})
  end

  test "create with :multipart correctly formats nested files", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      conn = prepare_conn(conn)

      params = conn.params
      test1 = params |> Map.get("one")
      test2 = params |> get_in(["two", "three"])
      test3 = params |> get_in(["two", "four"]) |> Enum.at(0)
      test4 = params |> get_in(["two", "four"]) |> Enum.at(1)

      assert "/" == conn.request_path
      assert "POST" == conn.method
      assert_upload(test1, "test1.txt", "text/plain")
      assert_upload(test2, "test2.txt", "text/plain")
      assert_upload(test3, "test3.txt", "text/plain")
      assert_upload(test4, "test4.txt", "text/plain")

      conn
    end

    {:ok, multipart} = %{
      one: FormData.File.new("test/fixtures/test1.txt"),
      two: %{
        three: FormData.File.new("test/fixtures/test2.txt"),
        four: [
          FormData.File.new("test/fixtures/test3.txt"),
          FormData.File.new("test/fixtures/test4.txt")
        ]
      }
    } |> FormData.create(:multipart)

    HTTPoison.post(url, multipart, %{})
  end

  test "create with :url_encoded correctly formats nested data", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      assert_request(
        conn,
        "/",
        "POST",
        %{
          "one" => "one",
          "two" => %{
            "three" => "three",
            "four" => [ "four1", "four2", "four3" ],
            "five" => [ "five1", "five2", %{ "six" => "six" } ]
          }
        },
        []
      )
    end

    {:ok, url_encoded} = %{
      one: "one",
      two: %{
        three: "three",
        four: [
          "four1",
          "four2",
          "four3"
        ],
        five: {
          "five1",
          "five2",
          %{
            six: "six"
          }
        }
      }
    } |> FormData.create(:url_encoded)

    HTTPoison.post(url, url_encoded)
  end

  test "create with :url_encoded correctly formats nested data with %{get: true}", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      assert_request(
        conn,
        "/",
        "GET",
        %{
          "one" => "one",
          "two" => %{
            "three" => "three",
            "four" => [ "four1", "four2", "four3" ],
            "five" => [ "five1", "five2", %{ "six" => "six" } ]
          }
        },
        []
      )
    end

    {:ok, url_encoded} = %{
      one: "one",
      two: %{
        three: "three",
        four: [
          "four1",
          "four2",
          "four3"
        ],
        five: {
          "five1",
          "five2",
          %{
            six: "six"
          }
        }
      }
    } |> FormData.create(:url_encoded, get: true)

    HTTPoison.get(url, %{}, url_encoded)
  end

  test "create with :url_encoded correctly formats nested data with %{url: true}", %{bypass: bypass, url: url} do
    Bypass.expect bypass, fn conn ->
      assert_request(
        conn,
        "/",
        "GET",
        %{
          "one" => "one",
          "two" => %{
            "three" => "three",
            "four" => [ "four1", "four2", "four3" ],
            "five" => [ "five1", "five2", %{ "six" => "six" } ]
          }
        },
        []
      )
    end

    {:ok, url_encoded} = %{
      one: "one",
      two: %{
        three: "three",
        four: [
          "four1",
          "four2",
          "four3"
        ],
        five: {
          "five1",
          "five2",
          %{
            six: "six"
          }
        }
      }
    } |> FormData.create(:url_encoded, url: true)

    (url <> url_encoded)
    |> HTTPoison.get(%{}, [])
  end
end
