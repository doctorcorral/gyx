# thanks https://extips.blackode.in/
# IEx.configure colors: [enabled: true]
# IEx.configure colors: [ eval_result: [ :cyan, :bright ] ]
#IO.puts IO.ANSI.light_black_background() <> IO.ANSI.white() <> " ❄❄❄❄  Elixir ❄❄❄❄ " <> IO.ANSI.reset
Application.put_env(:elixir, :ansi_enabled, true)
IEx.configure(
 colors: [
   eval_result: [:green, :bright] ,
   eval_error: [[:red,:bright,"▶ 🐛  Bug 🐛...!!! "]],
   eval_info: [:yellow, :bright ],
 ],
 default_prompt: [
   "\e[G",    # ANSI CHA, move cursor to column 1
    :white,
    "I",
    :red,
    " ❤ " ,       # plain string
    :green,
    "gyx",:white,"|", #%prefix
     :blue,
     "%counter",
     :white,
     "|",
    :blue,
    "▶" ,         # plain string
    :white,
    "▶▶"  ,       # plain string
      # ❤ ❤-»" ,  # plain string
    :reset
  ] |> IO.ANSI.format |> IO.chardata_to_string

)
