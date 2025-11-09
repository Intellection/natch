defmodule Natch.Conversion do
  @moduledoc """
  Conversion utilities between row-oriented and column-oriented data formats.

  Provides helpers for users with row-based data sources who need to convert
  to ClickHouse's native columnar format.

  ## Validation

  Type and length validation happens automatically in `Natch.Column.append_bulk/2`
  and the underlying FINE NIFs when you build blocks, providing type safety with
  optimal performance.
  """

  @type schema :: [{atom(), atom()}]

  @doc """
  Converts row-oriented data (list of maps) to column-oriented format (map of lists).

  ## Examples

      iex> rows = [
      ...>   %{id: 1, name: "Alice", age: 30},
      ...>   %{id: 2, name: "Bob", age: 25}
      ...> ]
      iex> schema = [id: :uint64, name: :string, age: :uint64]
      iex> Natch.Conversion.rows_to_columns(rows, schema)
      %{
        id: [1, 2],
        name: ["Alice", "Bob"],
        age: [30, 25]
      }
  """
  @spec rows_to_columns([map()], schema()) :: map()
  def rows_to_columns(rows, schema) when is_list(rows) and is_list(schema) do
    case rows do
      [] ->
        # Fast path: empty rows return empty columns
        Map.new(schema, fn {name, _type} -> {name, []} end)

      [first_row | _rest] ->
        column_names = Keyword.keys(schema)

        # Performance optimization: Detect key type ONCE from first row
        # This avoids checking both atom and string keys for every cell (2x speedup)
        key_type =
          if Map.has_key?(first_row, hd(column_names)) do
            :atom
          else
            :string
          end

        # Build optimized accessor function (no branching in hot loop)
        accessor =
          case key_type do
            :atom ->
              fn row, name ->
                Map.fetch!(row, name)
              end

            :string ->
              fn row, name ->
                Map.fetch!(row, Atom.to_string(name))
              end
          end

        # Initialize empty lists for each column
        initial_acc = Map.new(column_names, fn name -> {name, []} end)

        # Single traversal: accumulate all columns simultaneously
        columns_reversed =
          Enum.reduce(rows, initial_acc, fn row, acc ->
            Enum.reduce(column_names, acc, fn name, col_acc ->
              value = accessor.(row, name)
              # Prepend is O(1), reverse at the end
              Map.update!(col_acc, name, fn list -> [value | list] end)
            end)
          end)

        # Reverse all columns using Erlang's C implementation (faster)
        Map.new(columns_reversed, fn {name, values} -> {name, :lists.reverse(values)} end)
    end
  end

  @doc """
  Converts column-oriented data (map of lists) to row-oriented format (list of maps).

  Useful for testing or when you need row-based output.

  ## Examples

      iex> columns = %{
      ...>   id: [1, 2],
      ...>   name: ["Alice", "Bob"],
      ...>   age: [30, 25]
      ...> }
      iex> schema = [id: :uint64, name: :string, age: :uint64]
      iex> Natch.Conversion.columns_to_rows(columns, schema)
      [
        %{id: 1, name: "Alice", age: 30},
        %{id: 2, name: "Bob", age: 25}
      ]
  """
  @spec columns_to_rows(map(), schema()) :: [map()]
  def columns_to_rows(columns, schema) when is_map(columns) and is_list(schema) do
    column_names = Keyword.keys(schema)

    # Get all column lists upfront
    column_lists = Enum.map(column_names, fn name -> Map.fetch!(columns, name) end)

    # Handle empty case
    if Enum.all?(column_lists, &(&1 == [])) do
      []
    else
      # Zip all columns together and convert to maps - O(M) complexity
      column_lists
      |> Enum.zip()
      |> Enum.map(fn row_tuple ->
        row_tuple
        |> Tuple.to_list()
        |> Enum.zip(column_names)
        |> Map.new(fn {value, name} -> {name, value} end)
      end)
    end
  end
end
