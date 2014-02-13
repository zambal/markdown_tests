defmodule MarkdownTests do
  def benchmark(opts \\ []) do
    dirty_scheduler = if nil?(opts[:dirty_scheduler]), do: true, else: opts[:dirty_scheduler]
    doc_size        = opts[:doc_size] || 10000
    doc_times       = opts[:doc_times] || 200
    ring_multiplier = opts[:ring_multiplier] || 40
    doc(doc_size, doc_times, dirty_scheduler)
    ring(ring_multiplier) |> stats()
  end

  defp stats(timings) do
    len = length(timings)
    min = Enum.min(timings)
    max = Enum.max(timings)
    t40 = Enum.sort(timings) |> Enum.reverse() |> Enum.take(40)
    med = Enum.sort(timings) |> Enum.at(:erlang.round(len / 2))
    avg = (Enum.reduce(timings, 0, fn t, sum -> t + sum end) / len) |> :erlang.round()
    IO.puts "Sample size: #{len}"
    IO.puts "Range (microsecs): #{min} - #{max}"
    IO.puts "Median (microsecs): #{med}"
    IO.puts "Average (microsecs): #{avg}"
    IO.puts "Top 40 timings (microsecs): #{inspect t40}"
  end

  defp create_markdown(size) do
    size     = size * 1024 # size in KB
    doc      = concatenated_docs()
    doc_size = size(doc)
    copies   = :binary.copy(doc, div(size, doc_size))
    part     = :binary.part(doc, 0, rem(size, doc_size))
    copies <> part
  end

  defp doc(size, times, dirty_scheduler) do
    spawn(fn ->
      doc = create_markdown(size)
      t_start = :os.timestamp
      Enum.each(1..times, fn _ ->
        Markdown.to_html(doc, [], dirty_scheduler)
        receive do
          _ -> :ok
        after
          1 -> :ok
        end
      end)
      t_end = :os.timestamp
      IO.puts "Total markdown parsing timing (ms): #{:timer.now_diff(t_end, t_start) / 1000}"
    end)
  end
  
  defp ring(multiplier) do
    proc_count    = 1000
    message_count = proc_count * multiplier
    h = Enum.reduce(proc_count..2, self(), fn id, pid ->
      spawn(__MODULE__, :roundtrip, [id, pid])
    end)
    ts = :os.timestamp
    send(h, { message_count, [ts] })
    roundtrip(1, h)
  end

  def roundtrip(id, pid) do
    receive do
      { 1, [h | t] } ->
        ts = :os.timestamp
        [:timer.now_diff(ts, h) | t]
      { n, [h | t] } ->
        ts = :os.timestamp
        send(pid, { n - 1, [ts, :timer.now_diff(ts, h) | t] })
        roundtrip(id, pid)
    after
      2_000 -> :ok
    end
  end

  defp concatenated_docs() do
    lc p inlist :code.get_path(), String.match?(p, ~r/elixir/) do
      lc f inlist File.ls!(p), String.contains?(f, ".beam") and String.match?(f, ~r/^[A-Z]/) do
        mod = String.replace(f, ".beam", "") |> binary_to_atom()
        { _, mod_doc } = mod.__info__(:moduledoc) 
        mod_doc
      end |> Enum.filter(&is_binary(&1))
    end |> Enum.shuffle() |> iolist_to_binary()
  end
end
