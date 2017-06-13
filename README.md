# FormData

A library for formatting data to be used with
[HTTPoison](https://github.com/edgurgel/httpoison) and
[Hackney](https://github.com/benoitc/hackney).

This library was originally written to help with formatting data to upload files
for internal Spiceworks projects, but has expanded to include formatting all
`multipart` data for `POST` requests to work with `HTTPoison` and `Hackney`, in
addition to formatting `url encoded` requests for `POST` and `GET`, both with
the supported `HTTPoison` syntax and with a string to append to any URL.


## Installation

Add `httpoison_form_data` to your list of dependencies in `mix.exs`:

```elixir
def application do
  [applications: [:httpoison]]
end

def deps do
  [{:httpoison_form_data, "~> 0.1"},
   {:httpoison, "~> 0.11.2"}]
end
```

## Usage

The outermost layer in your nested structure MUST be a map, keyword list, or struct.

## Multipart Requests
```elixir
# This structure will be used in the following example
some_structure = %{
  first_key: "first_value",
  second_key: [
    "second_value",
    "third_value",
    %{
      third_key: "fourth_value",
      fourth_key: {
        "fifth_value",
        "sixth_value"
      }
    }
  ],
  fifth_key: FormData.File.new("path/to/file.txt")
}
```
#### Example 1
```elixir
with {:ok, payload} <- FormData.create(some_structure, :multipart),
  do: HTTPoison.post("some.url/", payload)

# The above code produces the following request
HTTPoison.post("some.url/", {
  :multipart,
  [
    {"", "first_value", {"form-data", [{"name", "\"first_key\""}]}, []},
    {"", "second_value", {"form-data", [{"name", "\"second_key[]\""}]}, []},
    {"", "third_value", {"form-data", [{"name", "\"second_key[]\""}]}, []},
    {"", "fourth_value", {"form-data", [{"name", "\"second_key[][third_key]\""}]}, []},
    {"", "fifth_value", {"form-data", [{"name", "\"second_key[][fourth_key][]\""}]}, []},
    {"", "sixth_value", {"form-data", [{"name", "\"second_key[][fourth_key][]\""}]}, []},
    {:file, "path/to/file.txt", {"form-data", [{"name", "\"fifth_key\""}, {"filename", "\"file.txt\""}]}, []}
  ]
})
```
### URL Encoded Requests
```elixir
# This structure will be used in the following examples
other_structure = %{
  one: "two",
  three: "four"
}
```
#### Example 2
```elixir
with {:ok, payload} <- FormData.create(other_structure, :url_encoded),
  do: HTTPoison.post("some.url/", payload)

# The above code produces the following request
HTTPoison.post("some.url/", {
  :form,
  [
    {"one", "two"},
    {"three", "four"}
  ]
})
```
#### Example 3
```elixir
with {:ok, payload} <- FormData.create(other_structure, :url_encoded, get: true),
  do: HTTPoison.get("some.url/", %{}, payload)

# The above code produces the following request
HTTPoison.get("some.url/", %{}, params: [
  {"one", "two"},
  {"three", "four"}
])
```

## Notes
Although the examples do not show this, `url_encoded` formdata supports nested
structures the same as `multipart`, but will ignore any `%FormData.File{}`
structs, since `url_encoded` requests do not support file uploads.

## Contributors
 - [Riley Trautman](https://github.com/asonix), asonix.dev@gmail.com

## Lincense
```
Copyright © 2016 Spiceworks, Inc.

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the LICENSE file for more details.
```
