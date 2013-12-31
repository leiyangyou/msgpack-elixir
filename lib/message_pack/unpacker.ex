defmodule MessagePack.Unpacker do

  defrecordp :options, [:enable_string]

  def unpack(binary, options // []) when is_binary(binary) do
    enable_string = if options[:enable_string] == true, do: true, else: false

    case do_unpack(binary, options(enable_string: enable_string)) do
      { :error, _ } = error ->
        error
      { result, "" } ->
        { :ok, result }
      { _, bin } when is_binary(bin) ->
        { :error, :not_just_binary }
    end
  end

  def unpack!(binary, options // []) when is_binary(binary) do
    case unpack(binary, options) do
      { :ok, result } ->
        result
      { :error, error } ->
        raise ArgumentError, message: inspect(error)
    end
  end

  def unpack_once(binary, options // []) when is_binary(binary) do
    enable_string = if options[:enable_string] == true, do: true, else: false

    case do_unpack(binary, options(enable_string: enable_string)) do
      { :error, _ } = error ->
        error
      result ->
        { :ok, result }
    end
  end

  def unpack_once!(binary, options // []) when is_binary(binary) do
    case unpack_once(binary, options) do
      { :ok, result } ->
        result
      { :error, error } ->
        raise ArgumentError, message: inspect(error)
    end
  end

  # positive fixnum
  defp do_unpack(<< 0 :: 1, v :: 7, rest :: binary >>, _), do: { v, rest }

  # negative fixnum
  defp do_unpack(<< 0b111 :: 3, v :: 5, rest :: binary >>, _), do: { v - 0b100000, rest }

  # uint
  defp do_unpack(<< 0xCC, uint :: [8, unsigned, integer], rest :: binary >>, _), do: { uint, rest }
  defp do_unpack(<< 0xCD, uint :: [16, big, unsigned, integer, unit(1)], rest :: binary >>, _), do: { uint, rest }
  defp do_unpack(<< 0xCE, uint :: [32, big, unsigned, integer, unit(1)], rest :: binary >>, _), do: { uint, rest }
  defp do_unpack(<< 0xCF, uint :: [64, big, unsigned, integer, unit(1)], rest :: binary >>, _), do: { uint, rest }

  # int
  defp do_unpack(<< 0xD0, int :: [8, signed, integer], rest :: binary >>, _), do: { int, rest }
  defp do_unpack(<< 0xD1, int :: [16, big, signed, integer, unit(1)], rest :: binary >>, _), do: { int, rest }
  defp do_unpack(<< 0xD2, int :: [32, big, signed, integer, unit(1)], rest :: binary >>, _), do: { int, rest }
  defp do_unpack(<< 0xD3, int :: [64, big, signed, integer, unit(1)], rest :: binary >>, _), do: { int, rest }

  # nil
  defp do_unpack(<< 0xC0, rest :: binary >>, _), do: { nil, rest }

  # boolean
  defp do_unpack(<< 0xC2, rest :: binary >>, _), do: { false, rest }
  defp do_unpack(<< 0xC3, rest :: binary >>, _), do: { true, rest }

  # float
  defp do_unpack(<< 0xCA, float :: [32, float, unit(1)], rest :: binary >>, _), do: { float, rest }
  defp do_unpack(<< 0xCB, float :: [64, float, unit(1)], rest :: binary >>, _), do: { float, rest }

  # old row format
  defp do_unpack(<< 0b101 :: 3, len :: 5, binary :: [size(len), binary], rest :: binary >>, options(enable_string: false)), do: { binary, rest }
  defp do_unpack(<< 0xDA, len :: [16, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, options(enable_string: false)), do: { binary, rest }
  defp do_unpack(<< 0xDB, len :: [32, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, options(enable_string: false)), do: { binary, rest }

  # string
  defp do_unpack(<< 0b101 :: 3, len :: 5, binary :: [size(len), binary], rest :: binary >>, options(enable_string: true)) do
    if String.valid?(binary) do
      { binary, rest }
    else
      { :error, { :invalid_string, binary } }
    end
  end
  defp do_unpack(<< 0xD9, len :: [8, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, options(enable_string: true)) do
    if String.valid?(binary) do
      { binary, rest }
    else
      { :error, { :invalid_string, binary } }
    end
  end
  defp do_unpack(<< 0xDA, len :: [16, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, options(enable_string: true)) do
    if String.valid?(binary) do
      { binary, rest }
    else
      { :error, { :invalid_string, binary } }
    end
  end
  defp do_unpack(<< 0xDB, len :: [32, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, options(enable_string: true)) do
    if String.valid?(binary) do
      { binary, rest }
    else
      { :error, { :invalid_string, binary } }
    end
  end

  # binary
  defp do_unpack(<< 0xC4, len :: [8,  unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, _), do: { binary, rest }
  defp do_unpack(<< 0xC5, len :: [16, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, _), do: { binary, rest }
  defp do_unpack(<< 0xC6, len :: [32, unsigned, integer, unit(1)], binary :: [size(len), binary], rest :: binary >>, _), do: { binary, rest }

  # array
  defp do_unpack(<< 0b1001 :: 4, len :: 4, rest :: binary >>, options), do: unpack_array(rest, len, options)
  defp do_unpack(<< 0xDC, len :: [16, big, unsigned, integer, unit(1)], rest :: binary >>, options), do: unpack_array(rest, len, options)
  defp do_unpack(<< 0xDD, len :: [32, big, unsigned, integer, unit(1)], rest :: binary >>, options), do: unpack_array(rest, len, options)

  # map
  defp do_unpack(<< 0b1000 :: 4, len :: 4, rest :: binary >>, options), do: unpack_map(rest, len, options)
  defp do_unpack(<< 0xDE, len :: [16, big, unsigned, integer, unit(1)], rest :: binary >>, options), do: unpack_map(rest, len, options)
  defp do_unpack(<< 0xDF, len :: [32, big, unsigned, integer, unit(1)], rest :: binary >>, options), do: unpack_map(rest, len, options)

  # invalid prefix
  defp do_unpack(<< 0xC1, _ :: binary >>, _), do: { :error, { :invalid_prefix, 0xC1 } }

  defp do_unpack(_, _), do: { :error, :incomplete }

  defp unpack_array(binary, len, options) do
    do_unpack_array(binary, len, [], options)
  end

  defp do_unpack_array(rest, 0, acc, _) do
    { :lists.reverse(acc), rest }
  end

  defp do_unpack_array(binary, len, acc, options) do
    case do_unpack(binary, options) do
      { :error, _ } = error ->
        error
      { term, rest } ->
        do_unpack_array(rest, len - 1, [term|acc], options)
    end
  end

  defp unpack_map(binary, 0, _) do
    { [{}], binary }
  end

  defp unpack_map(binary, len, options) do
    do_unpack_map(binary, len, [], options)
  end

  defp do_unpack_map(rest, 0, acc, _) do
    { :lists.reverse(acc), rest }
  end

  defp do_unpack_map(binary, len, acc, options) do
    case do_unpack(binary, options) do
      { :error, _ } = error ->
        error
      { key, rest } ->
        case do_unpack(rest, options) do
          { :error, _ } = error ->
            error
          { value, rest } ->
            do_unpack_map(rest, len - 1, [{key, value}|acc], options)
        end
    end
  end
end
