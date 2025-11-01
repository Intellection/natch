defmodule Chex.ConnectionError do
  @moduledoc """
  Raised when a connection to ClickHouse cannot be established.

  This error is raised when the client fails to connect to the ClickHouse server,
  typically due to network issues, invalid host/port, or DNS resolution failures.

  ## Fields

  - `:message` - Human-readable error description
  - `:reason` - Underlying system error reason (e.g., `:econnrefused`, `:nxdomain`)
  """

  defexception [:message, :reason]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)
    reason = Keyword.get(opts, :reason)

    %__MODULE__{
      message: message,
      reason: reason
    }
  end
end

defmodule Chex.ServerError do
  @moduledoc """
  Raised when ClickHouse server returns an error.

  This includes SQL syntax errors, table not found, permission errors, and other
  server-side errors reported by ClickHouse.

  ## Fields

  - `:message` - Human-readable error description from server
  - `:code` - ClickHouse error code (integer)
  - `:name` - Exception name from server (e.g., "DB::Exception")
  - `:stack_trace` - Server-side stack trace (optional)
  """

  defexception [:message, :code, :name, :stack_trace]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)
    code = Keyword.get(opts, :code)
    name = Keyword.get(opts, :name)
    stack_trace = Keyword.get(opts, :stack_trace)

    %__MODULE__{
      message: message,
      code: code,
      name: name,
      stack_trace: stack_trace
    }
  end
end

defmodule Chex.ValidationError do
  @moduledoc """
  Raised when client-side validation fails.

  This includes invalid column types, mismatched row counts, empty endpoint lists,
  and other client-side validation failures before data is sent to the server.

  ## Fields

  - `:message` - Human-readable validation error description
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)

    %__MODULE__{
      message: message
    }
  end
end

defmodule Chex.ProtocolError do
  @moduledoc """
  Raised when there's a protocol-level communication error.

  This includes I/O errors, serialization/deserialization failures, checksum
  mismatches, and other protocol-level issues.

  ## Fields

  - `:message` - Human-readable protocol error description
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)

    %__MODULE__{
      message: message
    }
  end
end

defmodule Chex.CompressionError do
  @moduledoc """
  Raised when compression or decompression fails.

  This includes LZ4/ZSTD compression failures, checksum mismatches in compressed
  data, and other compression-related errors.

  ## Fields

  - `:message` - Human-readable compression error description
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)

    %__MODULE__{
      message: message
    }
  end
end

defmodule Chex.UnimplementedError do
  @moduledoc """
  Raised when a requested feature is not implemented.

  This occurs when trying to use features not supported by the current ClickHouse
  server version or the client library.

  ## Fields

  - `:message` - Human-readable description of unimplemented feature
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)

    %__MODULE__{
      message: message
    }
  end
end

defmodule Chex.OpenSSLError do
  @moduledoc """
  Raised when SSL/TLS operations fail.

  This includes SSL context initialization failures, certificate errors, and other
  OpenSSL-related errors.

  ## Fields

  - `:message` - Human-readable SSL error description
  """

  defexception [:message]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.fetch!(opts, :message)

    %__MODULE__{
      message: message
    }
  end
end
