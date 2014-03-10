require 'test_helper'
require 'benchmark'

class BenchmarkTest < Test::Unit::TestCase
  def setup
    @prof = SamplingProf.new(0.01)
  end

  def test_profile_and_output_text_result
    t = 40
    puts "t: #{t}"
    Benchmark.bm do |x|
      x.report('warm up') do
        5.times { fib(t) }
      end
      x.report('no profiling') do
        fib(t)
      end
      x.report('with profiling') do
        @prof.profile { fib(t) }
      end
    end
  end

  def fib(i)
    if i == 1
      0
    elsif i == 2
      1
    else
      fib(i - 1) + fib(i - 2)
    end
  end
end
