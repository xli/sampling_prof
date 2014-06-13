require 'test_helper'
require 'stringio'
require 'fileutils'

class SamplingProfMultithreadingTest < Test::Unit::TestCase
  def setup
    @data = []
  end

  def teardown
    if @prof
      @prof.terminate
    end
  end

  def test_profiling_multithreading_together
    @prof = SamplingProf.new(0.01) do |data|
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
    start = Time.now
    thread1.join
    thread2.join
    time = Time.now - start
    @prof.terminate

    assert_equal 2, @data.size
    runtime, nodes, _ = @data[0].split("\n\n")

    assert runtime.to_f > time.to_i
    linums = nodes.split("\n").map{|a| a.split(':')}.select do |a|
      a[0] =~ /sampling_prof_multithreading_test.rb$/
    end.map do |a|
      a[1].to_i
    end

    #===============================================
    runtime, nodes, _ = @data[1].split("\n\n")

    assert runtime.to_f > time.to_i
    linums += nodes.split("\n").map{|a| a.split(':')}.select do |a|
      a[0] =~ /sampling_prof_multithreading_test.rb$/
    end.map do |a|
      a[1].to_i
    end

    assert linums.include?(23), "should include line number running thread1"
    assert linums.include?(29), "should include line number running thread2"
  end

  def test_caculate_runtime
    @prof = SamplingProf.new(0.005) do |data|
      @data << data
    end

    thread1 = Thread.start do
      @prof.profile do
        sleep 0.01
      end
    end
    thread2 = Thread.start do
      @prof.profile do
        sleep 0.02
      end
    end
    thread1.join
    thread2.join

    sleep 0.05

    @prof.terminate
    runtimes = @data.map do |d|
      d.split("\n\n").first.to_i
    end

    # puts "[DEBUG]runtimes => #{runtimes.inspect}"

    assert_equal 2, runtimes.size

    assert((runtimes[0] >= 10 && runtimes[0] <= 20), "first data collected runtime(#{runtimes[0]}) should >= 0.001 sec and <= 0.01 sec")
    assert((runtimes[1] >= 20 && runtimes[1] <= 30), "second data collected runtime(#{runtimes[0]}) should >= 0.02 sec and <= 0.03 sec")

    runtime = runtimes.reduce(:+)
    assert((runtime >= 30 && runtime <= 40), "runtime: #{runtime} should >= 0.03 sec and <= 0.04 sec")
  end

  def test_should_not_yield_output_handler_when_there_is_no_data_collected
    @prof = SamplingProf.new(0.01) do |data|
      @data << data
    end
    @prof.profile {}
    sleep 0.1
    @prof.terminate
    assert_equal [], @data
  end
end
