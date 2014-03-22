require 'test_helper'
require 'stringio'
require 'fileutils'

class SamplingProfMultithreadingTest < Test::Unit::TestCase
  def setup
    @data = []
  end

  def test_profiling_multithreading_together
    @prof = SamplingProf.new(0.01, true, 50) do |data|
      @data << data
    end

    thread1 = Thread.start do
      @prof.profile do
        fib(25)
      end
    end

    thread2 = Thread.start do
      @prof.profile do
        fib(25)
      end
    end
    thread1.join
    thread2.join

    @prof.terminate

    assert_equal 1, @data.size
    nodes, counts, call_graph = @data[0]
    linums = nodes.map{|a| a[0].split(':')}.select do |a|
      a[0] =~ /sampling_prof_multithreading_test.rb$/
    end.map do |a|
      a[1].to_i
    end

    assert linums.include?(17), "should include line number running thread1"
    assert linums.include?(23), "should include line number running thread2"
  end

  def test_handler_for_start_method_will_be_ignored
    @prof = SamplingProf.new(0.01, true, 50) do |data|
      @data << data
    end
    @prof.start(lambda {|d| raise "should not be called"})
    assert @prof.stop
    assert @prof.terminate
  end

  def test_use_default_flush_count
    @prof = SamplingProf.new(0.01, true) do |data|
      @data << data
    end
    @prof.start(lambda {|d| raise "should not be called"})
    assert @prof.stop
    assert_equal [], @data
    assert @prof.terminate
    assert_equal 1, @data.size
  end
end
