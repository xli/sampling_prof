require 'test_helper'
require 'stringio'
require 'fileutils'

class SamplingProfMultithreadingTest < Test::Unit::TestCase
  def setup
    @data = []
  end

  def test_profiling_multithreading_together
    @prof = SamplingProf.new(0.01, true) do |data|
      @data << data
    end

    thread1 = Thread.start do
      @prof.profile do
        fib(35)
      end
    end

    thread2 = Thread.start do
      @prof.profile do
        fib(35)
      end
    end
    thread1.join
    thread2.join

    @prof.terminate

    assert_equal 1, @data.size

    nodes = @data[0].split("\n\n")[0].split("\n")

    linums = nodes.map{|a| a.split(':')}.select do |a|
      a[0] =~ /sampling_prof_multithreading_test.rb$/
    end.map do |a|
      a[1].to_i
    end

    assert linums.include?(17), "should include line number running thread1"
    assert linums.include?(23), "should include line number running thread2"
  end

  def test_output_interval
    @prof = SamplingProf.new(0.01, true, 0.1) do |data|
      @data << data
    end

    thread1 = Thread.start do
      @prof.profile do
        fib(35)
      end
    end

    thread2 = Thread.start do
      @prof.profile do
        fib(35)
      end
    end
    thread1.join
    thread2.join

    @prof.terminate

    # no exact num can get, knowing bigger than 2 probably is good enough
    assert @data.size > 2
  end
end
