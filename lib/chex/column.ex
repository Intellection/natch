defmodule Chex.Column do
  @moduledoc """
  Column builder for ClickHouse native types.

  Provides an Elixir API for creating and populating ClickHouse columns.
  """

  alias Chex.Native

  @type column :: %__MODULE__{
          ref: reference(),
          type: atom(),
          clickhouse_type: String.t()
        }

  defstruct [:ref, :type, :clickhouse_type]

  @doc """
  Creates a new column of the specified type.

  ## Supported Types

  **Integers:**
  - `:uint64` - UInt64
  - `:uint32` - UInt32
  - `:uint16` - UInt16
  - `:int64` - Int64
  - `:int32` - Int32
  - `:int16` - Int16
  - `:int8` - Int8

  **Floats:**
  - `:float64` - Float64
  - `:float32` - Float32

  **Strings:**
  - `:string` - String

  **Dates/Times:**
  - `:datetime` - DateTime (Unix timestamp in seconds)
  - `:date` - Date (days since epoch)

  **Boolean:**
  - `:bool` - Bool (stored as UInt8)

  ## Examples

      iex> Chex.Column.new(:uint64)
      %Chex.Column{type: :uint64, clickhouse_type: "UInt64", ref: #Reference<...>}

      iex> Chex.Column.new(:string)
      %Chex.Column{type: :string, clickhouse_type: "String", ref: #Reference<...>}
  """
  @spec new(atom()) :: column()
  def new(type) when is_atom(type) do
    clickhouse_type = elixir_type_to_clickhouse(type)
    ref = Native.column_create(clickhouse_type)

    %__MODULE__{
      ref: ref,
      type: type,
      clickhouse_type: clickhouse_type
    }
  end

  @doc """
  Appends multiple values to the column in bulk (single NIF call).

  This is the primary, high-performance API. Values must be a list matching
  the column type.

  ## Examples

      col = Chex.Column.new(:uint64)
      :ok = Chex.Column.append_bulk(col, [1, 2, 3, 4, 5])

      col = Chex.Column.new(:string)
      :ok = Chex.Column.append_bulk(col, ["hello", "world"])

      col = Chex.Column.new(:datetime)
      :ok = Chex.Column.append_bulk(col, [~U[2024-01-01 10:00:00Z], ~U[2024-01-01 11:00:00Z]])
  """
  @spec append_bulk(column(), [term()]) :: :ok
  def append_bulk(%__MODULE__{type: :uint64, ref: ref}, values) when is_list(values) do
    # Validate all values
    unless Enum.all?(values, &(is_integer(&1) and &1 >= 0)) do
      raise ArgumentError, "All values must be non-negative integers for UInt64 column"
    end

    Native.column_uint64_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :int64, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &is_integer/1) do
      raise ArgumentError, "All values must be integers for Int64 column"
    end

    Native.column_int64_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :string, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &is_binary/1) do
      raise ArgumentError, "All values must be strings for String column"
    end

    Native.column_string_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :float64, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_float(&1) or is_integer(&1))) do
      raise ArgumentError, "All values must be numbers for Float64 column"
    end

    # Convert integers to floats
    float_values =
      Enum.map(values, fn
        val when is_float(val) -> val
        val when is_integer(val) -> val * 1.0
      end)

    Native.column_float64_append_bulk(ref, float_values)
  end

  def append_bulk(%__MODULE__{type: :datetime, ref: ref}, values) when is_list(values) do
    # Convert all to Unix timestamps
    timestamps =
      Enum.map(values, fn
        %DateTime{} = dt -> DateTime.to_unix(dt)
        timestamp when is_integer(timestamp) -> timestamp
        other -> raise ArgumentError, "Invalid datetime value: #{inspect(other)}"
      end)

    Native.column_datetime_append_bulk(ref, timestamps)
  end

  def append_bulk(%__MODULE__{type: :date, ref: ref}, values) when is_list(values) do
    # Convert all to days since epoch
    days =
      Enum.map(values, fn
        %Date{} = date ->
          Date.diff(date, ~D[1970-01-01])

        days when is_integer(days) ->
          days

        other ->
          raise ArgumentError, "Invalid date value: #{inspect(other)}"
      end)

    Native.column_date_append_bulk(ref, days)
  end

  def append_bulk(%__MODULE__{type: :bool, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &is_boolean/1) do
      raise ArgumentError, "All values must be booleans for Bool column"
    end

    # Convert booleans to 0/1
    int_values =
      Enum.map(values, fn
        true -> 1
        false -> 0
      end)

    Native.column_uint8_append_bulk(ref, int_values)
  end

  def append_bulk(%__MODULE__{type: :uint32, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_integer(&1) and &1 >= 0 and &1 <= 4_294_967_295)) do
      raise ArgumentError,
            "All values must be non-negative integers 0..4294967295 for UInt32 column"
    end

    Native.column_uint32_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :uint16, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_integer(&1) and &1 >= 0 and &1 <= 65_535)) do
      raise ArgumentError, "All values must be non-negative integers 0..65535 for UInt16 column"
    end

    Native.column_uint16_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :int32, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_integer(&1) and &1 >= -2_147_483_648 and &1 <= 2_147_483_647)) do
      raise ArgumentError,
            "All values must be integers -2147483648..2147483647 for Int32 column"
    end

    Native.column_int32_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :int16, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_integer(&1) and &1 >= -32_768 and &1 <= 32_767)) do
      raise ArgumentError, "All values must be integers -32768..32767 for Int16 column"
    end

    Native.column_int16_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :int8, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_integer(&1) and &1 >= -128 and &1 <= 127)) do
      raise ArgumentError, "All values must be integers -128..127 for Int8 column"
    end

    Native.column_int8_append_bulk(ref, values)
  end

  def append_bulk(%__MODULE__{type: :float32, ref: ref}, values) when is_list(values) do
    unless Enum.all?(values, &(is_float(&1) or is_integer(&1))) do
      raise ArgumentError, "All values must be numbers for Float32 column"
    end

    # Convert integers to floats
    float_values =
      Enum.map(values, fn
        val when is_float(val) -> val
        val when is_integer(val) -> val * 1.0
      end)

    Native.column_float32_append_bulk(ref, float_values)
  end

  def append_bulk(%__MODULE__{type: type}, values) when is_list(values) do
    raise ArgumentError,
          "Invalid values #{inspect(values)} for column type #{type}"
  end

  def append_bulk(%__MODULE__{}, values) do
    raise ArgumentError, "append_bulk/2 requires a list of values, got: #{inspect(values)}"
  end

  @doc """
  Returns the number of elements in the column.

  ## Examples

      col = Chex.Column.new(:uint64)
      Chex.Column.append(col, 1)
      Chex.Column.append(col, 2)
      Chex.Column.size(col)
      # => 2
  """
  @spec size(column()) :: non_neg_integer()
  def size(%__MODULE__{ref: ref}) do
    Native.column_size(ref)
  end

  # Private functions

  defp elixir_type_to_clickhouse(:uint64), do: "UInt64"
  defp elixir_type_to_clickhouse(:uint32), do: "UInt32"
  defp elixir_type_to_clickhouse(:uint16), do: "UInt16"
  defp elixir_type_to_clickhouse(:int64), do: "Int64"
  defp elixir_type_to_clickhouse(:int32), do: "Int32"
  defp elixir_type_to_clickhouse(:int16), do: "Int16"
  defp elixir_type_to_clickhouse(:int8), do: "Int8"
  defp elixir_type_to_clickhouse(:float64), do: "Float64"
  defp elixir_type_to_clickhouse(:float32), do: "Float32"
  defp elixir_type_to_clickhouse(:string), do: "String"
  defp elixir_type_to_clickhouse(:datetime), do: "DateTime"
  defp elixir_type_to_clickhouse(:date), do: "Date"
  defp elixir_type_to_clickhouse(:bool), do: "Bool"

  defp elixir_type_to_clickhouse(type) do
    raise ArgumentError, "Unsupported column type: #{inspect(type)}"
  end
end
