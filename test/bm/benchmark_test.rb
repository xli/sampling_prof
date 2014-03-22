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
        5.times { my_fib(t) }
      end
      x.report('no profiling') do
        my_fib(t)
      end
      x.report('with profiling') do
        @prof.profile { my_fib(t) }
      end
    end
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
