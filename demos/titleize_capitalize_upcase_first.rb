require 'benchmark'
require 'active_support/core_ext/string/inflections'

n = 100_000

Benchmark.bm(20) do |x|
  x.report("#titleize") do
    n.times { "mcCartney".titleize }
  end

  x.report("#capitalize") do
    n.times { "mcCartney".capitalize }
  end

  x.report("#upcase_first") do
    n.times { "mcCartney".upcase_first }
  end
end
