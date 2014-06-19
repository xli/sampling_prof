require 'test_helper'
require 'fileutils'

class SamplingProfTest < Test::Unit::TestCase
  def setup
    @prof = nil
  end

  def teardown
    @prof.terminate if @prof
  end

  def test_default_options
    @prof = SamplingProf.new
    assert_equal 0.1, @prof.sampling_interval
  end

  def test_start_and_stop_profiling
    @prof = SamplingProf.new(0.01)
    assert !@prof.profiling?
    assert !@prof.stop

    assert @prof.start(lambda{})

    assert !@prof.start(lambda{})
    assert @prof.profiling?

    assert @prof.stop

    assert !@prof.stop
    assert @prof.profiling?
    sleep 0.02
    assert !@prof.profiling?

    assert @prof.terminate
    assert !@prof.stop
    assert !@prof.profiling?
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_profile_and_output_text_result
    @prof = SamplingProf.new(0.01)
    FileUtils.rm_rf(SamplingProf::DEFAULT_OUTPUT_FILE)
    @prof.profile do
      fib(35)
    end
    sleep 0.02
    assert File.exist?(SamplingProf::DEFAULT_OUTPUT_FILE)
    runtime, nodes, counts, call_graph = File.read(SamplingProf::DEFAULT_OUTPUT_FILE).split("\n\n")

    assert runtime.to_f > 100 # unit is ms
    assert nodes.split("\n").size > 1
    assert counts.split("\n").size > 1
    assert call_graph.split("\n").size > 1
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_start_profile_with_specific_output_handler
    @data = nil
    @prof = SamplingProf.new(0.01) do |data|
      @data = data
    end
    @prof.profile do
      sleep 0.02
    end
    sleep 0.02
    assert @data
    assert !File.exist?(SamplingProf::DEFAULT_OUTPUT_FILE)
  end

  def test_output_handler_should_be_called_even_after_profiling_thread_is_dead
    @threads = []
    @prof = SamplingProf.new(0.01) do |data|
      @threads << Thread.current.status
    end
    t = Thread.start do
      @prof.profile do
        sleep 0.02
      end
    end
    t.join
    sleep 0.02
    assert_equal 'run', @threads[0]
  end

  def test_profile_with_temp_output_handler
    @data = []
    @prof = SamplingProf.new(0.01) do |data|
      # do nothing
    end
    @prof.profile(lambda {|data| @data << data}) do
      sleep 0.02
    end
    sleep 0.02
    assert_equal 1, @data.size
  end

  def test_should_not_yield_output_handler_when_there_is_no_data_collected
    @data = []
    @prof = SamplingProf.new(0.1) do |data|
      @data << data
    end
    sleep 0.01
    @prof.profile {}
    sleep 0.2
    @prof.terminate
    assert_equal [], @data
  end
end
