require 'set'
require 'thread'

class SamplingProf
  class Sampling
    def initialize
      @samples = Hash.new{|h,k| h[k] = [0, 0] }
      @call_graph = Hash.new{|h,k| h[k] = 0}
      @nodes = {}
      @start_at = Time.now
    end

    def runtime
      Time.now - @start_at
    end

    def sampling_data?
      !@nodes.empty?
    end

    def result
      ret = [runtime * 1000]
      ret << @nodes.map {|node| node.join(',')}.join("\n")
      ret << @samples.map {|count| count.flatten.join(',')}.join("\n")
      ret << @call_graph.map {|v| v.flatten.join(',')}.join("\n")
      "#{ret.join("\n\n")}\n"
    end

    def process(thread)
      locations = thread.backtrace_locations
      from = -1
      paths = []
      calls = []
      top_index = locations.size - 1
      locations.reverse.each_with_index do |loc, i|
        node_id = node_id(loc)
        if i == top_index
          @samples[node_id][0] += 1
        end

        path = [from, node_id]
        if !paths.include?(path)
          paths << path
          @call_graph[path] += 1
        end
        if !calls.include?(node_id)
          calls << node_id
          @samples[node_id][1] += 1
        end
        from = node_id
      end
    end

    def node_id(loc)
      @nodes[call_element(loc)] ||= @nodes.size
    end

    def call_element(loc)
      [loc.path, loc.lineno, loc.label].join(":")
    end
  end

  attr_accessor :sampling_interval, :output_handler, :profiling_threshold

  def internal_initialize
    @samplings = {}
    start_sampling_thread
  end

  def start
    unless @samplings.has_key?(Thread.current)
      @samplings[Thread.current] = Sampling.new
      true
    end
  end

  def stop
    if @running
      if sampling = @samplings.delete(Thread.current)
        if sampling.sampling_data?
          @output_handler.call(sampling.result)
        end
        true
      end
    end
  end

  def terminate
    return false unless @running
    @running = false
    @sampling_thread.join
    @sampling_thread = nil
    @samplings = {}
    true
  end

  def profiling?
    !!@sampling_thread && @samplings.has_key?(Thread.current)
  end

  private
  def start_sampling_thread
    return if @running
    @running = true
    @sampling_thread ||= Thread.start do
      loop do
        @samplings.dup.each do |t, s|
          if s.runtime >= @profiling_threshold
            s.process(t)
          end
        end
        sleep @sampling_interval
        break unless @running
      end
    end
  end
end
