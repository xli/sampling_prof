require 'test_helper'
require 'benchmark'

class BenchmarkTest < Test::Unit::TestCase
  def teardown
    @prof.terminate
  end

  def test_benchmark_profiling
    @prof = SamplingProf.new(0.1) do |data|
      # do nothing
    end
    t = 40
    tc = 16
    puts "t: #{t}, thread count: #{tc}"
    Benchmark.bm do |x|
      5.times do
        x.report('P') do
          threads = (1..tc).map do |i|
            Thread.start do
              @prof.profile { my_fib(t) }
              Thread.start { @prof.profile { my_fib(t) } }.join
            end
          end
          threads.each(&:join)
        end
        x.report('N') do
          threads = (1..tc).map do |i|
            Thread.start do
              my_fib(t)
              Thread.start { my_fib(t) }.join
            end
          end
          threads.each(&:join)
        end
      end
    end
  ensure
    @prof.terminate
  end

  def my_fib(i)
    if i == 1
      0
    elsif i == 2
      1
    else
      my_fib(i - 1) + my_fib(i - 2)
    end
  end

end
