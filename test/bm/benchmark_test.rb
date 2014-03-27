require 'test_helper'
require 'benchmark'

class BenchmarkTest < Test::Unit::TestCase
  def test_profile_and_output_text_result
    @prof = SamplingProf.new(0.01)
    t = 40
    puts "t: #{t}"
    Benchmark.bm do |x|
      x.report('warm up        ') do
        5.times { my_fib(t) }
      end
      x.report('no profiling   ') do
        my_fib(t)
      end
      x.report('with profiling ') do
        @prof.profile { my_fib(t) }
      end
    end
  end

  def test_multithreading_profiling
    @prof = SamplingProf.new(0.1, true, 1) do |data|
      # do nothing
    end
    t = 40
    tc = 16
    puts "t: #{t}, thread count: #{tc}"
    Benchmark.bm do |x|
      x.report('warm up        ') do
        5.times { my_fib(t) }
      end
      x.report('no profiling   ') do
        threads = (1..tc).map do |i|
          Thread.start do
            my_fib(t)
          end
        end
        threads.each(&:join)
      end
      x.report('with profiling ') do
        threads = (1..tc).map do |i|
          Thread.start do
            @prof.profile { my_fib(t) }
          end
        end
        threads.each(&:join)
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
